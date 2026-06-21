# frozen_string_literal: true

module SFL
  module Compiler
    module Chat
      # One Q&A exchange: the user's literal question plus the
      # ContextSynthesizer result it produced.
      ChatTurn = Struct.new(:query, :result, keyword_init: true)

      # Wraps ContextSynthesizer with conversation memory. Synthesize
      # itself is single-shot (query in, answer out) — multi-turn here
      # means folding recent Q&A into the query text before retrieval,
      # not modifying ContextSynthesizer itself.
      class Session
        attr_reader :turns

        # @param synthesizer [ContextSynthesizer]
        # @param filters [Hash] HybridRetriever scalar filters
        # @param limit [Integer] max clauses per retrieval
        # @param history_window [Integer] prior turns folded into each query
        def initialize(synthesizer:, filters: {}, limit: 10, history_window: 3)
          @synthesizer = synthesizer
          @filters = filters
          @limit = limit
          @history_window = history_window
          @turns = []
        end

        # @param query [String]
        # @return [Types::SynthesisResult]
        def ask(query)
          result = @synthesizer.synthesize(augmented_query(query), filters: @filters, limit: @limit)
          @turns << ChatTurn.new(query:, result:)
          result
        end

        def empty?
          @turns.empty?
        end

        private def augmented_query(query)
          return query if @turns.empty?

          history = @turns.last(@history_window).map { |t| "Q: #{t.query}\nA: #{t.result.answer}" }.join("\n\n")
          "Conversation so far:\n#{history}\n\nFollow-up question: #{query}"
        end
      end
    end
  end
end
