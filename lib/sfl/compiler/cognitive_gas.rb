# frozen_string_literal: true

require "circuit_breaker"

module SFL
  module Compiler
    # Semantic budget tracker for Pass 2 annotation loops.
    #
    # Implements the same `#call(&block)` interface as CircuitBreaker::CircuitHandler
    # so it can be injected as a drop-in replacement (or complement) in PassTwoEngine.
    #
    # Cost is computed from SFL-derived clause features available at Pass 1 output:
    # process_type complexity weight + token count + participant count. When
    # cumulative cost exceeds the budget, the next `#call` raises
    # CircuitBreaker::CircuitBrokenException, causing PassTwoEngine to fall back
    # to annotation defaults for that chunk.
    #
    # Budget is controlled by `COGNITIVE_GAS_BUDGET` env var (default 1000 units).
    # One "unit" is roughly the cost of one short relational clause (~2 tokens, 0
    # participants). A 40-clause conversation at medium complexity costs ~400 units.
    #
    # Thread safety: `@spent` is guarded by a Mutex for Sidekiq worker contexts.
    class CognitiveGas
      DEFAULT_BUDGET = 1_000

      # SFL process type → base gas cost (material/mental = cognitively expensive,
      # existential/relational = lightweight linking clauses).
      PROCESS_COSTS = {
        "material"    => 3,
        "mental"      => 3,
        "verbal"      => 2,
        "behavioral"  => 2,
        "relational"  => 1,
        "existential" => 1
      }.freeze

      DEFAULT_PROCESS_COST = 1
      TOKEN_CAP             = 20  # diminishing returns beyond 20 tokens

      # @param budget [Integer, nil] total gas units; reads COGNITIVE_GAS_BUDGET env if nil
      def initialize(budget: nil)
        @budget = (budget || ENV.fetch("COGNITIVE_GAS_BUDGET", DEFAULT_BUDGET)).to_i
        @spent  = 0
        @mutex  = Mutex.new
      end

      attr_reader :budget, :spent

      def remaining  = @budget - @spent
      def exhausted? = @spent >= @budget

      # Drop-in circuit_breaker.call { block } interface.
      # Raises CircuitBreaker::CircuitBrokenException when budget is exhausted.
      def call(&block)
        raise CircuitBreaker::CircuitBrokenException,
          "Cognitive gas budget exhausted (#{@spent}/#{@budget} units spent)" if exhausted?

        block.call
      end

      # Accumulate cost for a batch of clause entries.
      # Accepts either Hash entries ({ clause:, ideational: }) or [clause, ideational] pairs.
      #
      # @param batch [Array] chunk entries from annotate_chunk
      # @return [Integer] cost charged for this batch
      def charge_batch(batch)
        cost = batch.sum { |entry| entry_cost(entry) }
        @mutex.synchronize { @spent += cost }
        cost
      end

      # Explicit single charge (for testing or manual accounting).
      # @param amount [Integer]
      def charge(amount)
        @mutex.synchronize { @spent += amount.to_i }
      end

      # Reset spent counter (invoked by Rolling Synthesis after compression).
      def reset!
        @mutex.synchronize { @spent = 0 }
      end

      private

      def entry_cost(entry)
        if entry.is_a?(Hash)
          clause     = entry[:clause]
          ideational = entry[:ideational]
        else
          clause, ideational = entry
        end

        return DEFAULT_PROCESS_COST unless clause && ideational

        process_cost     = PROCESS_COSTS.fetch(ideational.process_type.to_s, DEFAULT_PROCESS_COST)
        token_cost       = [clause.tokens.size, TOKEN_CAP].min
        participant_cost = ideational.participants.size

        process_cost + token_cost + participant_cost
      end
    end
  end
end
