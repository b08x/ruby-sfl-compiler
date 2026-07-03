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
      # @param include_fallback [Boolean] When false (default), clauses
      #   whose interpersonal annotation came from the Pass 2 degradation
      #   ladder (annotation_source "fallback"/"stub") are excluded from
      #   what the LLM sees and from what citations can reference — a
      #   fallback 0.5 shouldn't silently ground an answer. They still
      #   appear in `clauses:` (the full retrieved set is always reported).
      # @return [Types::SynthesisResult]
      def synthesize(query, filters: {}, limit: 10, include_fallback: false)
        rows = @retriever.retrieve(query, limit: limit, filters: filters)
        return Types::SynthesisResult.new(query: query, answer: nil, retrieved_count: 0, confidence: nil) if rows.empty?

        enriched = rows.map { |row| row.merge(annotations: @clause_repo.find(row[:clause_id])) }
        clauses = enriched.map { |e| public_clause_view(e) }
        citable, preamble = partition_citable(enriched, include_fallback)

        if citable.empty?
          return Types::SynthesisResult.new(
            query: query, answer: preamble, clauses: clauses,
            retrieved_count: rows.size, confidence: nil
          )
        end

        synthesize_from_citable(query, citable, clauses, rows.size, preamble)
      end

      private

      # Splits enriched rows into what the LLM may see/cite vs what's
      # excluded for carrying a fallback/stub interpersonal annotation,
      # and the Data Quality preamble describing that split (nil when
      # nothing was excluded).
      def partition_citable(enriched, include_fallback)
        citable = include_fallback ? enriched : enriched.select { |row| llm_sourced?(row) }
        [citable, data_quality_preamble(enriched.size - citable.size, enriched.size)]
      end

      # Unlike Pass 2, a failed synthesis call propagates — there is no
      # useful default "answer".
      def synthesize_from_citable(query, citable, clauses, retrieved_count, preamble)
        output = @synthesizer.call(query, format_evidence(citable))
        cited = map_citations(output[:cited_clause_numbers], citable)

        Types::SynthesisResult.new(
          query: query, answer: prepend_data_quality(output[:answer], preamble),
          cited_clause_ids: cited.uniq, clauses: clauses,
          retrieved_count: retrieved_count, confidence: output[:confidence]
        )
      rescue Dry::Struct::Error => e
        degraded_result(query, clauses, retrieved_count, e)
      end

      def degraded_result(query, clauses, retrieved_count, error)
        $stderr.puts "[WARN] Context synthesis (#{query}): invalid synthesizer output: " \
          "#{error.message} — returning evidence without an answer"
        Types::SynthesisResult.new(
          query: query, answer: nil, clauses: clauses,
          retrieved_count: retrieved_count, confidence: nil
        )
      end

      def map_citations(numbers, citable)
        Array(numbers).filter_map { |number| citable[number - 1]&.fetch(:clause_id) if number.positive? }
      end

      # Defensively treats a missing/nil annotation_source (rows stored
      # before this column existed) as trusted rather than excluding them.
      # "human" counts as trusted alongside "llm" — a reviewer-supplied
      # correction is not a compiler-substituted default.
      def llm_sourced?(enriched_row)
        source = enriched_row.dig(:annotations, :interpersonal, :annotation_source)
        source.nil? || Types::TRUSTED_ANNOTATION_SOURCES.include?(source)
      end

      # Flattens the scalar SFL fields callers actually want to display
      # (mood/tenor/modality/process_type/annotation_source) onto the
      # retrieved row, dropping the nested :annotations hash (which also
      # carries non-JSON-safe DB row bits like :embedding). Consumed by
      # the Safe RAG Hypothesis Validator view to show evidence stance
      # alongside each cited clause.
      def public_clause_view(enriched_row)
        interpersonal = enriched_row.dig(:annotations, :interpersonal) || {}
        ideational = enriched_row.dig(:annotations, :ideational) || {}

        enriched_row.reject { |k, _| k == :annotations }.merge(
          mood: interpersonal[:mood],
          tenor: interpersonal[:tenor],
          modality_weight: interpersonal[:modality_weight],
          process_type: ideational[:process_type],
          annotation_source: interpersonal[:annotation_source]
        )
      end

      def data_quality_preamble(excluded_count, total_count)
        return nil if excluded_count.zero?

        "_Data Quality: #{excluded_count}/#{total_count} retrieved clauses excluded due to fallback annotation._"
      end

      def prepend_data_quality(answer, preamble)
        return answer unless preamble

        "#{preamble}\n\n#{answer}"
      end

      def format_evidence(enriched)
        enriched.each_with_index.map do |row, idx|
          annotations_hash = row[:annotations] || {}
          interpersonal = annotations_hash[:interpersonal] || {}
          ideational = annotations_hash[:ideational] || {}
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
