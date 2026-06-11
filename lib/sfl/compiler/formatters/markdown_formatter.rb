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
