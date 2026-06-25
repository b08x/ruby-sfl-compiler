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
            **#{unit_label}s**: #{result.metadata[:turn_count]} | **#{actors_list_label}**: #{result.metadata[:speakers]&.join(', ')}
            #{data_quality_warning}
            ---

            ## Summary

            This analysis tracks **tenor evolution** (formality shifts), **field evolution** (topic/process changes), and **tenor ↔ field correlations** across the conversation.

            ---

            ## #{actor_label} Profiles

            #{speaker_profiles_table}

            ---

            ## Cohesion Metrics

            #{cohesion_table}

            ---

            ## Tenor ↔ Field Correlations

            #{correlations_table}

            ---

            ## Generated Insights

            #{insights_list}
            #{topic_modeling_section}
            #{key_moments_section}
            #{example_passages_section}
            #{reasoning_traces_section}
            ---

            ## Methodology

            **SFL Framework**: Two-Pass SFL Compiler (sfl-compiler)
            - **Pass 1**: Syntactic parsing (spaCy) + Ideational extraction (process types, participants)
            - **Pass 2**: Interpersonal annotation (DSPy.rb + LLM) → mood, modality, tenor, attitude

            **Tenor Scale**: 0.0 (informal/casual) ↔ 1.0 (formal/technical)
            **Modality Scale**: 0.0 (hedged/uncertain) ↔ 1.0 (certain/assertive)
          MD
        end

        # Clauses whose interpersonal values came from the Pass 2 fallback or
        # a Pass-1-only stub all sit at the scale midpoint (0.5/0.5/declarative),
        # which silently drags every aggregate toward "mixed". Surface that.
        private def data_quality_warning
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

          "#{warning}\n"
        end

        private def actor_label
          result.metadata[:actor_label] || "Speaker"
        end

        private def unit_label
          result.metadata[:unit_label] || "Turn"
        end

        private def actors_list_label
          result.metadata[:actors_list_label] || "Speakers"
        end

        private def speaker_profiles_table
          return "_No speaker profiles available_" if result.speaker_profiles.empty?

          name_pad = [actor_label.length, 7].max
          header = "| #{actor_label.ljust(name_pad)} | Avg Tenor | Range | Variance | Avg Modality |\n"
          header += "|#{'-' * (name_pad + 2)}|-----------|-------|----------|--------------|\n"

          rows = result.speaker_profiles.map do |name, profile|
            "| #{name.to_s.ljust(name_pad)} | #{profile.avg_tenor.round(3)} (#{tenor_label(profile.avg_tenor)}) | " \
              "[#{profile.tenor_range.map { |v| v.round(2) }.join(', ')}] | " \
              "#{profile.tenor_variance.round(4)} | #{profile.avg_modality.round(3)} |"
          end

          header + rows.join("\n")
        end

        private def cohesion_table
          header = "| #{unit_label} | Speaker | Repetition | Conjunctions | Pronouns |\n"
          header += "|:-----|:---------|:-----------|:-------------|:---------|\n"

          rows = result.turns.map do |turn|
            c = turn.cohesion
            next unless c

            "| #{turn.turn_id} | #{turn.speaker} | #{c.repetition_score.round(3)} | " \
              "#{c.conjunction_density.round(3)} | #{c.pronoun_density.round(3)} |"
          end.compact

          return "_No cohesion metrics available_" if rows.empty?

          header + rows.join("\n")
        end

        private def correlations_table
          return "_No correlations available_" if result.correlations.empty?

          header = "| Process Type | Avg Tenor | Avg Modality | Count |\n"
          header += "|--------------|-----------|--------------|-------|\n"

          rows = result.correlations.map do |process_type, data|
            next unless data.is_a?(Hash) && data[:count]

            "| #{process_type} | #{data[:avg_tenor].round(3)} | #{data[:avg_modality].round(3)} | #{data[:count]} |"
          end.compact

          header + rows.join("\n")
        end

        private def insights_list
          return "_No insights generated_" if result.insights.empty?

          result.insights.map.with_index { |insight, i| "#{i + 1}. #{insight}" }.join("\n\n")
        end

        private def topic_modeling_section
          return "" unless result.topic_labels&.any?

          section = ["", "### 🏷️ Topic Modeling", ""]
          section << "**#{result.topic_labels.size} topics identified**\n"

          result.topic_labels.each do |topic_id, words|
            top_words = words.first(5).join(", ")
            section << "- **Topic #{topic_id}**: #{top_words}"
          end

          if result.topic_evolution&.any?
            section << ""
            section << "**Topic Evolution:**"
            result.topic_evolution.each do |evolution|
              topic_words = result.topic_labels[evolution[:dominant_topic]]&.first(3)&.join(", ") || "topic #{evolution[:dominant_topic]}"
              section << "- #{unit_label} #{evolution[:turn_id]}: #{topic_words}"
            end
          end

          section.join("\n")
        end

        private def key_moments_section
          return "" if result.key_moments.empty?

          section = ["", "### ⚡ Key Moments", ""]
          result.key_moments.each do |moment|
            section << "- **#{unit_label} #{moment.turn_id}** (#{moment.type.tr('_', ' ')}): #{moment.description}"
          end
          section.join("\n")
        end

        private def example_passages_section
          return "" if result.example_passages.empty?

          section = ["", "### 📖 Example Passages", ""]
          result.example_passages.each do |passage|
            section << "#### #{passage.label} (score: #{passage.value.round(3)})"
            section << "> \"#{passage.text.gsub("\n", ' ').strip}\""
            section << ""
            section << "*— #{passage.speaker}. #{passage.reason}.*"
            section << ""
          end
          section.join("\n")
        end

        # Clauses with reasoning_trace: nil (fallback/stub annotation_source)
        # render nothing here — same "fallback values aren't presented as
        # findings" principle as #data_quality_warning.
        private def reasoning_traces_section
          traced = result.turns.flat_map(&:clauses).select { |c| c.interpersonal.reasoning_trace }
          return "" if traced.empty?

          section = ["", "### 🔍 Reasoning Traces", ""]
          traced.each { |clause| section.concat(reasoning_trace_block(clause)) }
          section.join("\n")
        end

        private def reasoning_trace_block(clause)
          trace = clause.interpersonal.reasoning_trace
          block = [
            "> \"#{clause.text.gsub("\n", ' ').strip}\"",
            "",
            "<details>",
            "<summary>Reasoning: #{trace.inference_rule} (confidence #{trace.confidence.round(2)})</summary>",
            "",
          ]
          block.concat(premises_table(trace.premises)) if trace.premises.any?
          block << "Derivation: `#{trace.derivation_hash}`"
          block << "</details>"
          block << ""
          block
        end

        private def premises_table(premises)
          rows = premises.map do |p|
            "| #{p.source} | #{p.type} | #{p.value} | #{p.weight.nil? ? '—' : p.weight} |"
          end
          ["| Premise | Type | Value | Weight |", "|---|---|---|---|", *rows, ""]
        end

        private def tenor_label(tenor)
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
