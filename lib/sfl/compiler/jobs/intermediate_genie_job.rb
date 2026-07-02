# frozen_string_literal: true

require "gush"
require "dspy"

module SFL
  module Compiler
    # Gush::Job that compresses a window of AnnotatedClauses into an
    # Axiomatic summary — the "Genie" compression step in the rolling
    # synthesis cycle.
    #
    # Params:
    #   :clause_ids   [Array<String>] external IDs from the `clauses` table
    #   :workflow_id  [String]        Gush workflow context (default "standalone")
    #   :lm           [String]        DSPy LM provider string (falls back to config)
    #
    # Output payload:
    #   { summary_id:, summary_text:, core_claim:,
    #     avg_tenor:, avg_modality:, clause_count:,
    #     process_type_distribution:, mood_distribution: }
    #
    # The summary_id is the UUID written to `axiomatic_summaries`; downstream
    # jobs (e.g. the next SprintRoleJob cycle) receive it as their prior_output.
    class IntermediateGenieJob < Gush::Job
      # DSPy signature for the Genie compression role.
      class AxiomaticSummarySignature < DSPy::Signature
        description "You are the Genie role in a rolling synthesis sprint. " \
                    "Compress the provided SFL-annotated clause evidence into a " \
                    "concise axiomatic summary that preserves the core interpersonal " \
                    "stance, dominant process type, and key participant relationships. " \
                    "The summary will serve as the axiomatic base for the next reasoning " \
                    "cycle — it must be self-contained and recoverable without the originals."

        input do
          const :clause_evidence, String,
            description: "Numbered clauses with text + SFL annotations (mood, tenor, modality, process type)"
          const :sfl_aggregates, String,
            description: "Statistical summary of the batch: process distribution, avg tenor/modality, mood histogram"
        end

        output do
          const :summary, String,
            description: "Compressed axiomatic prose (2-4 sentences, self-contained)"
          const :core_claim, String,
            description: "Single most salient interpersonal claim from this batch"
          const :confidence, Float,
            description: "0.0-1.0 confidence in the compression quality"
        end
      end

      def perform
        ctx = Bootstrap.call(require_db: true, require_llm: true, require_observability: false)

        clause_ids   = params.fetch(:clause_ids)
        workflow_id  = params.fetch(:workflow_id, "standalone")
        lm_provider  = params[:lm] || ctx.config.dspy_provider

        clause_repo  = ClauseRepository.new(ctx.db)
        summary_repo = AxiomaticSummaryRepository.new(ctx.db)

        rows = clause_ids.filter_map { |id| clause_repo.find(id) }

        aggregates   = build_aggregates(rows)
        evidence     = format_evidence(rows)
        generated    = generate_summary(evidence, aggregates, lm_provider)

        record = summary_repo.store(
          workflow_id:,
          source_clause_ids: clause_ids,
          summary_text:    generated[:summary],
          core_claim:      generated[:core_claim],
          **aggregates
        )

        output(
          summary_id:   record[:id],
          summary_text: generated[:summary],
          core_claim:   generated[:core_claim],
          **aggregates
        )
      end

      private

      def build_aggregates(rows)
        return empty_aggregates if rows.empty?

        total        = rows.size.to_f
        interpersonal = rows.map { |r| r[:interpersonal] }.compact
        ideational    = rows.map { |r| r[:ideational] }.compact

        process_dist = ideational.map { |i| i[:process_type] }.tally
          .transform_values { |v| (v / total).round(3) }

        mood_dist = interpersonal.map { |i| i[:mood] }.tally
          .transform_values { |v| (v / total).round(3) }

        participants = ideational.flat_map { |i|
          Array(i[:participants]).map { |p|
            p.is_a?(Hash) ? (p["text"] || p[:text]) : nil
          }.compact
        }.tally.sort_by { |_, c| -c }.first(10).map(&:first)

        {
          process_type_distribution: process_dist,
          avg_tenor:    mean(interpersonal.map { |i| i[:tenor].to_f }),
          avg_modality: mean(interpersonal.map { |i| i[:modality_weight].to_f }),
          mood_distribution: mood_dist,
          key_participants: participants,
          clause_count: rows.size
        }
      end

      def format_evidence(rows)
        rows.each_with_index.map do |row, idx|
          clause = row[:clause]
          inter  = row[:interpersonal]
          idea   = row[:ideational]
          next unless clause

          mood     = inter&.[](:mood)       || "?"
          tenor    = inter&.[](:tenor)&.round(2) || "?"
          modality = inter&.[](:modality_weight)&.round(2) || "?"
          process  = idea&.[](:process_type) || "?"

          "[#{idx + 1}] #{clause[:text]}\n" \
          "    [mood=#{mood} tenor=#{tenor} modality=#{modality} process=#{process}]"
        end.compact.join("\n")
      end

      def format_aggregates(agg)
        [
          "Process distribution: #{agg[:process_type_distribution].map { |k, v| "#{k}=#{(v * 100).round}%" }.join(", ")}",
          "Avg tenor: #{agg[:avg_tenor].round(3)} | Avg modality: #{agg[:avg_modality].round(3)}",
          "Mood distribution: #{agg[:mood_distribution].map { |k, v| "#{k}=#{(v * 100).round}%" }.join(", ")}",
          "Key participants: #{agg[:key_participants].first(5).join(", ")}",
          "Clause count: #{agg[:clause_count]}"
        ].join("\n")
      end

      def generate_summary(evidence, aggregates, lm_provider)
        predictor = DSPy::ChainOfThought.new(AxiomaticSummarySignature)
        predictor.configure do |c|
          c.lm = DSPy::LM.new(lm_provider,
            api_key: Bootstrap.api_key_for(lm_provider, ENV))
        end

        result = predictor.call(
          clause_evidence: evidence,
          sfl_aggregates:  format_aggregates(aggregates)
        )

        { summary: result.summary, core_claim: result.core_claim }
      rescue => e
        { summary: prose_fallback(aggregates), core_claim: "" }
      end

      def prose_fallback(agg)
        dominant_process = agg[:process_type_distribution].max_by { |_, v| v }&.first || "mixed"
        dominant_mood    = agg[:mood_distribution].max_by { |_, v| v }&.first || "declarative"
        "Axiomatic summary (#{agg[:clause_count]} clauses): dominant process=#{dominant_process}, " \
        "mood=#{dominant_mood}, avg_tenor=#{agg[:avg_tenor].round(2)}, avg_modality=#{agg[:avg_modality].round(2)}."
      end

      def empty_aggregates
        { process_type_distribution: {}, avg_tenor: 0.5, avg_modality: 0.5,
          mood_distribution: {}, key_participants: [], clause_count: 0 }
      end

      def mean(values)
        return 0.0 if values.empty?
        values.sum / values.size.to_f
      end
    end
  end
end
