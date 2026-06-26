# frozen_string_literal: true

require "gush"

module SFL
  module Compiler
    # Dynamic Gush workflow: loads all sections from a markdown/PDF path,
    # fans out one CompileSectionJob per section (no dependencies between
    # them — parallel across Sidekiq workers), then fans into one
    # ReduceSectionsJob that runs cross-section aggregation.
    #
    # Mirrors ConversationAnalysisWorkflow's shape exactly, with sections
    # replacing turns. The optional TopicModelJob pre-pass works the same
    # way when topics: is requested and there are ≥3 sections.
    class DocumentationAnalysisWorkflow < Gush::Workflow
      # topics: is not yet supported — a TopicModelDocJob (working on
      # pre-loaded section_data instead of a jsonl_path) is needed first.
      def configure(path, store: false, sprint_id: nil)
        section_data = load_section_data(path)
        total = section_data.size

        section_jobs = section_data.each_with_index.map do |datum, idx|
          run CompileSectionJob, params: { section_datum: datum, section_id: idx + 1, store: }
        end

        run ReduceSectionsJob,
          params: { path:, total:, store:, sprint_id:, sections_meta: sections_meta(section_data) },
          after: section_jobs
      end

      # Loads sections from the path and serializes each to a plain Hash so
      # the workflow configure method stores only JSON-compatible data in
      # Gush's Redis-backed workflow state. Mirrors DocumentationAnalyzer#load_sections
      # but returns hashes instead of [Section, mtime, pdf_chunk] tuples.
      private def load_section_data(path)
        files = File.directory?(path) ? Dir.glob(File.join(path, "**", "*.{md,pdf}")) : [path]
        files.flat_map do |file|
          mtime = File.mtime(file).iso8601
          pdf_chunk = File.extname(file).casecmp(".pdf").zero?
          loader = pdf_chunk ? PdfLoader : MarkdownLoader
          loader.load(file).map do |section|
            {
              text: section.text,
              heading: section.heading,
              file_id: section.file_id,
              document_id: section.document_id,
              mtime:,
              pdf_chunk:,
            }
          end
        end
      end

      # Minimal per-section metadata forwarded to ReduceSectionsJob so it
      # can reconstruct the section tuples needed for chunk-artifact detection.
      # Only file_id, heading, and pdf_chunk are used by the detector.
      private def sections_meta(section_data)
        section_data.map { |d| d.slice(:file_id, :heading, :pdf_chunk) }
      end
    end
  end
end
