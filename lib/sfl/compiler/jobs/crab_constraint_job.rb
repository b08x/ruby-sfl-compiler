# frozen_string_literal: true

# See compile_turn_job.rb's file-top comment — same reason this file
# requires "gush" directly rather than relying on Bootstrap's require.
require "gush"

module SFL
  module Compiler
    # Crab's role in the sprint pattern: pin invariants, reject claims that
    # violate them. Rule-based, not an LLM call — kept separate from
    # SprintRoleJob (which is purely DSPy-backed) rather than folded into
    # its template method, which would mix concerns and violate SRP.
    #
    # Invariants are plain JSON-safe data (`{name:, field:, op:, value:}`),
    # never Procs. Gush::Job#to_json serializes `params` to Redis when a
    # job crosses a Sidekiq process boundary — a `check: ->(claim) { ... }`
    # Proc (as an earlier draft of this job's spec proposed) cannot survive
    # that round trip. The small fixed OPERATORS registry below is the
    # serializable equivalent: domain tracks supply *data* describing the
    # check, this job supplies the *code* that runs it.
    class CrabConstraintJob < Gush::Job
      OPERATORS = {
        "eq" => -> (actual, expected) { actual == expected },
        "neq" => -> (actual, expected) { actual != expected },
        "gt" => -> (actual, expected) { actual.to_f > expected.to_f },
        "gte" => -> (actual, expected) { actual.to_f >= expected.to_f },
        "lt" => -> (actual, expected) { actual.to_f < expected.to_f },
        "lte" => -> (actual, expected) { actual.to_f <= expected.to_f },
        "present" => -> (actual, _expected) { !(actual.nil? || actual == "") },
        "absent" => -> (actual, _expected) { actual.nil? || actual == "" },
      }.freeze

      def perform
        prior_output = payloads.find { |p| p[:class] == "SprintRoleJob" }.fetch(:output)
        claims = Array(prior_output[claims_field] || prior_output[claims_field.to_sym])
        invariants = params.fetch(:invariants, [])

        passed = []
        rejected = []
        violations = []

        claims.each do |claim|
          violation = first_violation(claim, invariants)
          if violation
            rejected << claim
            violations << violation
          else
            passed << claim
          end
        end

        output(passed_claims: passed, rejected_claims: rejected, violations:)
      end

      private def claims_field
        params.fetch(:claims_field, "claims")
      end

      private def first_violation(claim, invariants)
        invariants.each do |invariant|
          field = fetch_either(invariant, :field)
          op = fetch_either(invariant, :op)
          expected = fetch_either(invariant, :value)
          actual = fetch_either(claim, field)

          next if OPERATORS.fetch(op).call(actual, expected)

          return {
            "name" => fetch_either(invariant, :name),
            "field" => field,
            "reason" => "expected #{field} #{op} #{expected.inspect}, got #{actual.inspect}",
          }
        end
        nil
      end

      private def fetch_either(hash, key)
        hash[key.to_s] || hash[key.to_sym]
      end
    end
  end
end
