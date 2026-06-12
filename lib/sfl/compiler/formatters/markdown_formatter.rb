# frozen_string_literal: true

module SFL
  module Compiler
    module Formatters
      # Exports conversation analysis to Markdown report
      class MarkdownFormatter < BaseFormatter
        def render
          <<~MD
            # Conversation Analysis: #{result.metadata[:conversation_id]}

            **Generated**: #{result.metadata[:analyzed_at]}
            **Turns**: #{result.metadata[:turn_count]} | **Speakers**: #{result.metadata[:speakers]&.join(", ")}
            #{data_quality_warning}
            ---

            ## Summary

            This analysis tracks **tenor evolution** (formality shifts), **field evolution** (topic/process changes), and **tenor ↔ field correlations** across the conversation.

            ---

            ## Speaker Profiles

            #{speaker_profiles_table}

            ---

            ## Tenor ↔ Field Correlations

            #{correlations_table}

            ---

            ## Generated Insights

            #{insights_list}

            ---

            ## Methodology

            **SFL Framework**: Two-Pass SFL Compiler (sfl-compiler)
            - **Pass 1**: Syntactic parsing (spaCy) + Ideational extraction (process types, participants)
            - **Pass 2**: Interpersonal annotation (DSPy.rb + LLM) → mood, modality, tenor, attitude

            **Tenor Scale**: 0.0 (informal/casual) ↔ 1.0 (formal/technical)
            **Modality Scale**: 0.0 (hedged/uncertain) ↔ 1.0 (certain/assertive)
          MD
        end

        private

        # Clauses whose interpersonal values came from the Pass 2 fallback or
        # a Pass-1-only stub all sit at the scale midpoint (0.5/0.5/declarative),
        # which silently drags every aggregate toward "mixed". Surface that.
        def data_quality_warning
          clauses = result.turns.flat_map(&:clauses)
          return "" if clauses.empty?

          defaulted = clauses.count { |c| c.interpersonal.annotation_source != "llm" }
          return "" if defaulted.zero?

          pct = (defaulted * 100.0 / clauses.size).round(1)
          warning = <<~WARN.chomp

            ---

            ## ⚠️ Data Quality

            **#{defaulted} of #{clauses.size} clauses (#{pct}%)** carry fallback/stub interpersonal values (tenor=0.5, modality=0.5, mood=declarative) instead of LLM annotations. Tenor and modality averages are biased toward 0.5.
          WARN

          if defaulted == clauses.size
            warning += "\n\n**Pass 2 did not run for any clause — the interpersonal values in this report are placeholders, not findings.**"
          end

          warning + "\n"
        end

        def speaker_profiles_table
          return "_No speaker profiles available_" if result.speaker_profiles.empty?

          header = "| Speaker | Avg Tenor | Range | Variance | Avg Modality |\n"
          header += "|---------|-----------|-------|----------|--------------|\n"

          rows = result.speaker_profiles.map do |name, profile|
            "| #{name} | #{profile.avg_tenor} (#{tenor_label(profile.avg_tenor)}) | #{profile.tenor_range.inspect} | #{profile.tenor_variance} | #{profile.avg_modality} |"
          end

          header + rows.join("\n")
        end

        def correlations_table
          return "_No correlations available_" if result.correlations.empty?

          header = "| Process Type | Avg Tenor | Avg Modality | Count |\n"
          header += "|--------------|-----------|--------------|-------|\n"

          rows = result.correlations.map do |process_type, data|
            "| #{process_type} | #{data[:avg_tenor]} | #{data[:avg_modality]} | #{data[:count]} |"
          end

          header + rows.join("\n")
        end

        def insights_list
          return "_No insights generated_" if result.insights.empty?

          result.insights.map.with_index { |insight, i| "#{i + 1}. #{insight}" }.join("\n\n")
        end

        def tenor_label(tenor)
          case tenor
          when 0.0..0.3 then "casual"
          when 0.3..0.6 then "mixed"
          when 0.6..1.0 then "formal"
          else "unknown"
          end
        end
      end
    end
  end
end
