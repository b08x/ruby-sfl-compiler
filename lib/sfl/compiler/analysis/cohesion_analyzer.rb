# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Analyzes text flow and reference density across clauses.
      # Implements the Textual metafunction analysis at the aggregation level.
      class CohesionAnalyzer
        # @param turns [Array<Types::ConversationTurn>]
        # @return [Array<Types::ConversationTurn>] mutated turns with cohesion metrics
        def analyze(turns)
          turns.map do |turn|
            metrics = calculate_metrics(turn.clauses)
            turn.new(cohesion: metrics)
          end
        end

        private

        def calculate_metrics(clauses)
          return default_metrics if clauses.empty?

          all_tokens = clauses.flat_map { |c| c.syntactic.tokens }
          return default_metrics if all_tokens.empty?

          Types::CohesionMetrics.new(
            repetition_score: calculate_repetition(all_tokens),
            conjunction_density: calculate_density(all_tokens, /CCONJ|SCONJ/),
            pronoun_density: calculate_density(all_tokens, "PRON")
          )
        end

        # Lexical Repetition: 1.0 - (unique_content / total_content)
        def calculate_repetition(tokens)
          content_lemmas = tokens.select { |t| t.pos =~ /NOUN|VERB|ADJ|ADV/ }.map(&:lemma).map(&:downcase)
          return 0.0 if content_lemmas.size <= 1

          unique_count = content_lemmas.uniq.size
          (1.0 - (unique_count.to_f / content_lemmas.size)).clamp(0.0, 1.0)
        end

        def calculate_density(tokens, pos_pattern)
          count = tokens.count { |t| t.pos.to_s.match?(pos_pattern) }
          (count.to_f / tokens.size).clamp(0.0, 1.0)
        end

        def default_metrics
          Types::CohesionMetrics.new(
            repetition_score: 0.0,
            conjunction_density: 0.0,
            pronoun_density: 0.0
          )
        end
      end
    end
  end
end
