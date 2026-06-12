# frozen_string_literal: true

require "dspy"

module SFL
  module Compiler
    # Answers a natural-language query from previously stored clauses:
    # hybrid retrieval (RRF + scalar stance filters) feeds a numbered,
    # SFL-annotated evidence block to an LLM synthesis call. Citations
    # come back as evidence numbers and are mapped to clause ids here —
    # out-of-range numbers are dropped (don't trust LLM references).
    class ContextSynthesizer
      # @param retriever [HybridRetriever]
      # @param clause_repo [ClauseRepository]
      # @param synthesizer [#call, nil] (query, evidence) → Hash with
      #   :answer, :cited_clause_numbers, :confidence. Defaults to the
      #   DSPy-backed SFLSynthesizer.
      def initialize(retriever:, clause_repo:, synthesizer: nil)
        @retriever = retriever
        @clause_repo = clause_repo
        @synthesizer = synthesizer || ->(query, evidence) { SFLSynthesizer.new(query, evidence).call }
      end

      # @param query [String]
      # @param filters [Hash] HybridRetriever scalar filters
      #   (:mood, :min_tenor, :max_tenor, :min_modality, :max_modality, :process_type)
      # @param limit [Integer]
      # @return [Types::SynthesisResult]
      def synthesize(query, filters: {}, limit: 10)
        rows = @retriever.retrieve(query, limit: limit, filters: filters)

        if rows.empty?
          return Types::SynthesisResult.new(
            query: query, answer: nil, retrieved_count: 0, confidence: nil
          )
        end

        enriched = rows.map { |row| row.merge(annotations: @clause_repo.find(row[:clause_id])) }
        output = @synthesizer.call(query, format_evidence(enriched))

        cited = Array(output[:cited_clause_numbers]).filter_map do |number|
          enriched[number - 1]&.fetch(:clause_id) if number.positive?
        end

        Types::SynthesisResult.new(
          query: query,
          answer: output[:answer],
          cited_clause_ids: cited.uniq,
          clauses: enriched.map { |e| e.reject { |k, _| k == :annotations } },
          retrieved_count: rows.size,
          confidence: output[:confidence]
        )
      end

      private

      def format_evidence(enriched)
        enriched.each_with_index.map do |row, idx|
          interpersonal = row.dig(:annotations, :interpersonal) || {}
          ideational = row.dig(:annotations, :ideational) || {}
          annotations = [
            "mood=#{interpersonal[:mood]}",
            "tenor=#{interpersonal[:tenor]}",
            "modality=#{interpersonal[:modality_weight]}",
            "process=#{ideational[:process_type]}"
          ].join(", ")

          "[#{idx + 1}] #{row[:text]}\n    (#{annotations}; source: #{row[:document_id]})"
        end.join("\n")
      end
    end

    # DSPy signature for evidence-grounded answer synthesis.
    class SynthesisSignature < DSPy::Signature
      description "Answer the query using ONLY the numbered evidence clauses. " \
                  "Each clause carries SFL annotations (mood, tenor, modality, " \
                  "process type) — use them to weigh certainty and stance: " \
                  "low modality means the source hedges; tenor signals register. " \
                  "Cite the clause numbers you relied on. If the evidence is " \
                  "insufficient to answer, say so rather than invent."

      input do
        const :query, String, description: "The user's question"
        const :evidence, String,
          description: "Numbered clauses with text and SFL annotations"
      end

      output do
        const :answer, String, description: "Answer grounded in the evidence"
        const :cited_clause_numbers, T::Array[Integer],
          description: "Evidence numbers actually used (subset of the input numbering)"
        const :confidence, Float,
          description: "0.0-1.0, lower when evidence is thin or conflicting"
      end
    end

    # Default DSPy-backed synthesizer (mirrors SFLBatchAnnotator's role
    # for PassTwoEngine).
    class SFLSynthesizer
      def initialize(query, evidence)
        @query = query
        @evidence = evidence
      end

      # @return [Hash] :answer, :cited_clause_numbers, :confidence
      def call
        predictor = DSPy::ChainOfThought.new(SynthesisSignature)
        result = predictor.call(query: @query, evidence: @evidence)

        {
          answer: result.answer,
          cited_clause_numbers: result.cited_clause_numbers,
          confidence: result.confidence
        }
      end
    end
  end
end
