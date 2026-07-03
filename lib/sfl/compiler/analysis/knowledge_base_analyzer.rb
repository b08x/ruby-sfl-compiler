# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Analyzes a directory or file set as a knowledge base corpus rather
      # than as a conversation: each document section becomes a KnowledgeArtifact
      # with a content_type classification, quality_score, and migration_action
      # recommendation.
      #
      # Supports .md, .pdf, and (optionally) image files. Image analysis
      # requires a vision-capable LLM and is disabled by default — pass
      # `analyze_images: true` to enable it.
      #
      # Returns a Types::KnowledgeBaseReport, not an AnalysisResult.
      class KnowledgeBaseAnalyzer
        include Aggregations

        # .docx/.xlsx/.pptx/.html route through PdfLoader (kreuzberg-backed
        # — its Kreuzberg.extract_file_sync call auto-detects format from
        # the file itself, so nothing about that loader is actually
        # PDF-specific; verified against real .html and .docx files before
        # wiring this in rather than trusting kreuzberg's 75+-format claim
        # blind). .canvas is Obsidian's own JSON node-graph format and
        # needs its own loader (CanvasLoader), not kreuzberg.
        KREUZBERG_EXTENSIONS = %w[.pdf .docx .xlsx .pptx .html].freeze
        TEXT_EXTENSIONS  = (%w[.md .canvas] + KREUZBERG_EXTENSIONS).freeze
        IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .webp].freeze
        STALENESS_MONTHS = 18

        # @param pipeline [Pipeline]
        # @param clause_repo [ClauseRepository, nil] required only for store: true
        # @param on_progress [#call, nil]
        #   called with { artifact_id:, total:, title: } before each section
        # @param stop_requested [#call, nil] polled once per artifact; if it
        #   returns truthy the loop halts and a partial report is returned
        def initialize(pipeline:, clause_repo: nil, on_progress: nil, stop_requested: nil)
          @pipeline       = pipeline
          @clause_repo    = clause_repo
          @on_progress    = on_progress
          @stop_requested = stop_requested
          @classifier     = ContentTypeClassifier.new
          @scorer         = QualityScorer.new
          @assessor       = MigrationAssessor.new
        end

        # @param path [String] a file or directory
        # @param store [Boolean] persist clauses + embeddings
        # @param resume [Boolean] reuse cached Pass 2 results
        # @param analyze_images [Boolean] run vision LLM on image files
        #   (expensive — disabled by default)
        # @param vision_model [String, nil] RubyLLM model id for image
        #   description; nil uses the configured default
        # @return [Types::KnowledgeBaseReport]
        def analyze(path, store: false, resume: false, analyze_images: false, vision_model: nil)
          @resume = resume

          tuples = load_all_sections(path.to_s, analyze_images:, vision_model:)
          total  = tuples.size

          skipped = []
          artifacts = tuples.each_with_index.each_with_object([]) do |((section, source_file, mtime, source_type), idx), acc|
            break acc if @stop_requested&.call

            artifact_id = idx + 1
            @on_progress&.call(artifact_id:, total:, title: section_title(section))
            file_meta = { source_file:, mtime:, source_type: }
            begin
              acc << compile_artifact(section, artifact_id, store, file_meta)
            rescue => e
              # Same degradation ladder as Pass 2: one malformed vault file
              # (bad frontmatter, unparseable content) must not abort a
              # whole-corpus run — a Date-typed title at artifact 10 once
              # killed a 1295-artifact batch and all its prior LLM spend.
              # Interrupts (Ctrl+C) are not StandardError and still abort.
              skipped << { artifact_id:, source_file:, error: e.message }
              warn "[WARN] KB artifact #{artifact_id} (#{source_file}) skipped: #{e.message}"
            end
          end

          manifest = artifacts.map do |a|
            @assessor.assess(
              artifact_id:   a.artifact_id,
              title:         a.title,
              source_file:   a.source_file,
              content_type:  a.content_type,
              quality_score: a.quality_score
            )
          end

          # Backfill migration_action/reason from manifest into artifacts so
          # the artifact structs are self-contained (report consumers don't
          # need to cross-reference).
          manifest_index = manifest.to_h { |m| [m.artifact_id, m] }
          artifacts = artifacts.map do |a|
            entry = manifest_index[a.artifact_id]
            a.new(migration_action: entry.action, migration_reason: entry.reason)
          end

          Types::KnowledgeBaseReport.new(
            metadata: {
              source_path:      path.to_s,
              analyzed_at:      Time.now.iso8601,
              artifact_count:   artifacts.size,
              file_count:       tuples.map { |(_, f, _)| f }.uniq.size,
              images_analyzed:  analyze_images,
              store:,
              skipped_count:    skipped.size,
              skipped:          skipped,
            },
            artifacts:,
            migration_manifest:        manifest,
            content_type_distribution: type_distribution(artifacts),
            quality_distribution:      quality_buckets(artifacts),
            staleness_flags:           staleness_flags(artifacts)
          )
        end

        private

        def load_all_sections(path, analyze_images:, vision_model:)
          files = collect_files(path, analyze_images:)

          files.flat_map do |file|
            ext = File.extname(file).downcase
            mtime  = File.mtime(file)
            loader = loader_for(ext, vision_model:)
            next [] unless loader

            source_type = source_type_for(ext)
            loader.call(file).map { |section| [section, file, mtime, source_type] }
          rescue => e
            warn "[WARN] KnowledgeBaseAnalyzer: skipping #{file}: #{e.message}"
            []
          end
        end

        def source_type_for(ext)
          case ext
          when ".md"             then "vault_markdown"
          when ".canvas"         then "vault_canvas"
          when *IMAGE_EXTENSIONS then "vault_image"
          when *KREUZBERG_EXTENSIONS
            "vault_#{ext.delete_prefix('.')}" # vault_pdf, vault_docx, vault_xlsx, vault_pptx, vault_html
          else "vault_document"
          end
        end

        def collect_files(path, analyze_images:)
          extensions = TEXT_EXTENSIONS + (analyze_images ? IMAGE_EXTENSIONS : [])

          if File.directory?(path)
            Dir.glob(File.join(path, "**", "*")).select do |f|
              File.file?(f) && extensions.include?(File.extname(f).downcase)
            end.sort
          else
            [path]
          end
        end

        def loader_for(ext, vision_model:)
          case ext
          when ".md"     then ->(p) { MarkdownLoader.load(p) }
          when ".canvas" then ->(p) { CanvasLoader.load(p) }
          when *KREUZBERG_EXTENSIONS
            ->(p) { PdfLoader.load(p) }
          when *IMAGE_EXTENSIONS
            ->(p) { ImageLoader.new(p, vision_model:).sections }
          end
        end

        def section_title(section)
          # Frontmatter values are typed by YAML, not by us: an unquoted
          # `title: 2026-06-08` parses as a Date (MarkdownLoader's
          # safe_load permits Date for the `last updated:` field), and a
          # Daily note titled that way crashed KnowledgeArtifact's
          # String-typed :title 10 artifacts into a 1295-artifact run.
          # Same coercion compile_artifact already applies to tags.
          fm_title = section.frontmatter&.dig("title")&.to_s
          return fm_title unless fm_title.nil? || fm_title.strip.empty?

          section.heading || section.file_id
        end

        def compile_artifact(section, artifact_id, store, file_meta)
          source_file, mtime, source_type = file_meta.values_at(:source_file, :mtime, :source_type)
          frontmatter  = section.frontmatter
          last_updated = parse_last_updated(frontmatter&.dig("last updated") ||
                                            frontmatter&.dig("last_updated")) || mtime
          tags         = Array(frontmatter&.dig("tags")).map(&:to_s)

          @clause_repo&.delete_by_document(section.document_id) if store
          clauses = @pipeline.compile(
            section.text,
            document_id: section.document_id,
            store:,
            embed: store,
            resume: @resume,
            source_type:
          )

          content_type  = @classifier.classify(section:, clauses:, frontmatter:)
          quality_score = @scorer.score(clauses:, last_updated:)

          llm_count = clauses.count { |c| c.interpersonal.annotation_source == "llm" }
          human_count = clauses.count { |c| c.interpersonal.annotation_source == "human" }

          Types::KnowledgeArtifact.new(
            artifact_id:,
            title:        section_title(section),
            source_file:,
            section_path: section.heading,
            content_type:,
            quality_score:,
            migration_action: :review,   # overwritten after assessment pass
            migration_reason: "",
            tags:,
            last_updated:,
            clauses:,
            avg_tenor:    mean(clauses.map { |c| c.interpersonal.tenor }),
            avg_modality: mean(clauses.map { |c| c.interpersonal.modality_weight }),
            dominant_mood: clauses.map { |c| c.interpersonal.mood }.tally
                                  .max_by { |_, n| n }&.first || "declarative",
            process_types: clauses.map { |c| c.ideational.process_type }.tally,
            annotation_coverage: {
              llm:      llm_count,
              human:    human_count,
              fallback: clauses.size - llm_count - human_count,
              total:    clauses.size
            }
          )
        end

        def parse_last_updated(value)
          return nil unless value

          Time.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        def type_distribution(artifacts)
          artifacts.group_by(&:content_type).transform_values(&:size)
        end

        def quality_buckets(artifacts)
          {
            high:   artifacts.count { |a| a.quality_score >= 0.65 },
            medium: artifacts.count { |a| a.quality_score >= 0.40 && a.quality_score < 0.65 },
            low:    artifacts.count { |a| a.quality_score < 0.40 },
          }
        end

        def staleness_flags(artifacts)
          cutoff = Time.now - (STALENESS_MONTHS * 30 * 24 * 60 * 60)
          artifacts.filter_map do |a|
            next unless a.last_updated && a.last_updated < cutoff

            { artifact_id: a.artifact_id, title: a.title, last_updated: a.last_updated.iso8601 }
          end
        end
      end
    end
  end
end
