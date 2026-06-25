# frozen_string_literal: true

# See compile_turn_job.rb's file-top comment — same reason this file
# requires "gush" directly rather than relying on Bootstrap's require.
require "gush"

module SFL
  module Compiler
    # One LLM-backed sprint role (Achilles=propose, Tortoise=challenge,
    # Genie=synthesize) in the shared Achilles/Tortoise/Crab/Genie sprint
    # pattern. A single generic job class parameterized by `signature_class`
    # and `lm`, run three times with different params, rather than three
    # bespoke job classes — see track-shared-sprint-role-substrate's brief.
    #
    # `role` in params is informational only (job-graph clarity / future
    # logging); #perform doesn't branch on it — the signature class and LM
    # provider fully determine behavior.
    #
    # Crab's invariant pinning is rule-based, not an LLM call, so it lives
    # in the separate CrabConstraintJob rather than this class — folding it
    # in here would violate SRP (see that job's own file comment).
    class SprintRoleJob < Gush::Job
      def perform
        Bootstrap.call(require_db: false, require_llm: false, require_observability: false)

        signature_class = Object.const_get(params.fetch(:signature_class))
        predictor = DSPy::ChainOfThought.new(signature_class)
        predictor.configure { |c| c.lm = build_lm(params.fetch(:lm)) }

        input = params.fetch(:input, {}).transform_keys(&:to_sym)
        result = predictor.call(**input)

        output(result.to_h)
      end

      private def build_lm(provider)
        DSPy::LM.new(provider, api_key: Bootstrap.api_key_for(provider, ENV))
      end
    end
  end
end
