# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Classifies a knowledge-base section into a content type using a
      # two-stage heuristic:
      #
      #   1. Pre-SFL: text patterns and frontmatter tags that don't need
      #      the pipeline result (fast, no LLM required).
      #   2. Post-SFL: interpersonal + ideational signals from compiled
      #      clauses when pre-SFL heuristics can't decide.
      #
      # Returns one of the KBContentType enum values defined in Types.
      class ContentTypeClassifier
        AI_DISCLAIMER    = /ai responses?\s+may\s+include\s+mistakes/i.freeze
        CODE_BLOCK_RATIO = 0.25   # fraction of raw text in backtick spans
        MIN_CODE_CHARS   = 80     # minimum code characters before ratio applies

        TAG_MAP = {
          draft:               %w[draft wip work-in-progress in-progress],
          tutorial:            %w[tutorial how-to guide step-by-step walkthrough],
          technical_reference: %w[reference api documentation spec specification],
          research_note:       %w[research analysis study notes literature-review],
        }.freeze

        # @param section [MarkdownLoader::Section]
        # @param clauses [Array<Types::AnnotatedClause>]
        # @param frontmatter [Hash, nil]
        # @return [Symbol] one of Types::KBContentType values
        def classify(section:, clauses:, frontmatter: nil)
          text = section.text.to_s
          tags = normalised_tags(frontmatter)

          return :image          if frontmatter&.dig("content_type") == "image"
          return :ai_generated   if text.match?(AI_DISCLAIMER)
          return :draft          if tag_match?(tags, :draft)
          return :tutorial       if tag_match?(tags, :tutorial)
          return :technical_reference if tag_match?(tags, :technical_reference)
          return :research_note  if tag_match?(tags, :research_note)
          return :code_snippet   if code_heavy?(section.text.to_s)
          return :index          if stub_section?(clauses, text)

          from_sfl(clauses) || :research_note
        end

        private

        def normalised_tags(frontmatter)
          Array(frontmatter&.dig("tags")).map { |t| t.to_s.downcase }
        end

        def tag_match?(tags, type)
          patterns = TAG_MAP.fetch(type)
          tags.any? { |t| patterns.any? { |p| t.include?(p) } }
        end

        # More than CODE_BLOCK_RATIO of the raw text is inside backtick spans.
        def code_heavy?(raw_text)
          code_chars = raw_text.scan(/`[^`\n]+`|```[\s\S]*?```/).sum(&:length)
          return false if code_chars < MIN_CODE_CHARS

          code_chars.to_f / [raw_text.length, 1].max > CODE_BLOCK_RATIO
        end

        # Very short sections with almost no clauses are navigation/index nodes.
        def stub_section?(clauses, text)
          clauses.size <= 2 && text.length < 250
        end

        # Use SFL interpersonal + ideational signals as a tie-breaker.
        def from_sfl(clauses)
          return nil if clauses.empty?

          avg_modality    = mean_modality(clauses)
          dominant_mood   = tally_dominant(clauses.map { |c| c.interpersonal.mood })
          dominant_process = tally_dominant(clauses.map { |c| c.ideational.process_type })

          if avg_modality > 0.7 && dominant_mood == "declarative"
            :technical_reference
          elsif dominant_process == "material" && dominant_mood == "imperative"
            :tutorial
          elsif dominant_process == "mental"
            :research_note
          end
        end

        def mean_modality(clauses)
          vals = clauses.map { |c| c.interpersonal.modality_weight }
          vals.sum / vals.size.to_f
        end

        def tally_dominant(values)
          values.tally.max_by { |_, n| n }&.first
        end
      end
    end
  end
end
