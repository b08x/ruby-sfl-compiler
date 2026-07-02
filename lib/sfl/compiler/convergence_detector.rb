# frozen_string_literal: true

require "journald/logger"

module SFL
  module Compiler
    # Detects semantic convergence in rolling synthesis loops.
    #
    # Each call to #check embeds an Axiomatic summary and computes its cosine
    # similarity to the previous checkpoint embedding. When similarity exceeds
    # the threshold, the loop has stopped producing new information — the caller
    # should force a circuit break to avoid wasting CognitiveGas.
    #
    # Example:
    #   detector = ConvergenceDetector.new(embedder: embedder, threshold: 0.97)
    #   result = detector.check(summary_text, clauses_consumed: 42)
    #   # => { converged: false, similarity: 0.91, cycles: 1 }
    class ConvergenceDetector
      DEFAULT_THRESHOLD        = 0.97
      DEFAULT_CHECKPOINT_EVERY = 1

      # @param embedder [Embedder] embedding provider
      # @param threshold [Float] cosine similarity at which to signal convergence (0-1)
      # @param checkpoint_every [Integer] compare only every N calls (1 = every call)
      def initialize(embedder:, threshold: DEFAULT_THRESHOLD,
                     checkpoint_every: DEFAULT_CHECKPOINT_EVERY)
        @embedder         = embedder
        @threshold        = threshold.to_f
        @checkpoint_every = checkpoint_every.to_i.clamp(1, Float::INFINITY).to_i
        @cycles           = 0
        @last_embedding   = nil
        @last_similarity  = nil
        @logger           = Journald::Logger.new("sfl-compiler-convergence")
      end

      attr_reader :cycles, :last_similarity

      # Embed summary_text and check convergence against the previous checkpoint.
      #
      # @param summary_text [String]
      # @param clauses_consumed [Integer] how many source clauses this cycle covered
      # @return [Hash] { converged: bool, similarity: Float|nil, cycles: Integer }
      def check(summary_text, clauses_consumed: 0)
        @cycles += 1

        embedding = @embedder.embed(summary_text)

        result = if embedding.nil?
          { converged: false, similarity: nil, cycles: @cycles }
        elsif @last_embedding.nil? || !checkpoint_cycle?
          @last_embedding = embedding
          { converged: false, similarity: nil, cycles: @cycles }
        else
          similarity = cosine_similarity(@last_embedding, embedding)
          @last_similarity = similarity
          @last_embedding  = embedding
          { converged: similarity >= @threshold, similarity:, cycles: @cycles }
        end

        log_audit(result[:converged], result[:similarity], clauses_consumed)
        result
      end

      # Reset state (e.g. when starting a new synthesis sprint).
      def reset!
        @cycles          = 0
        @last_embedding  = nil
        @last_similarity = nil
      end

      private

      def checkpoint_cycle?
        @cycles % @checkpoint_every == 0
      end

      def cosine_similarity(a, b)
        dot    = a.zip(b).sum { |x, y| x * y }
        norm_a = Math.sqrt(a.sum { |x| x**2 })
        norm_b = Math.sqrt(b.sum { |x| x**2 })
        return 0.0 if norm_a.zero? || norm_b.zero?

        (dot / (norm_a * norm_b)).clamp(-1.0, 1.0)
      end

      def log_audit(converged, similarity, clauses_consumed)
        @logger.send_message(
          message:          "convergence_check",
          priority:         converged ? Journald::LOG_WARNING : Journald::LOG_INFO,
          cycles:           @cycles,
          similarity:       similarity&.round(4),
          threshold:        @threshold,
          converged:,
          clauses_consumed:
        )
      end
    end
  end
end
