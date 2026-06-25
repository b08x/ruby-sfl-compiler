# frozen_string_literal: true

require "digest"
require "json"

module SFL
  module Compiler
    # Shared canonical-hashing algorithm for reasoning-trace provenance,
    # used by both PassTwoEngine#reasoning_trace_from (computing the hash
    # at annotation time) and CrabConstraintJob's "derivation_hash_reproducible"
    # invariant (re-deriving it later to check for divergence). Kept as one
    # module rather than duplicated in each call site — two independently
    # maintained copies of a "did this hash get tampered with" check would
    # silently drift apart, defeating the point of the check.
    #
    # Accepts premises as either Types::Premise/PremiseOutput instances or
    # plain Hashes (the latter is what CrabConstraintJob sees, since by the
    # time it reads a prior job's payload, everything has been through a
    # real JSON round trip via Redis) — keys are stringified before hashing
    # so symbol-keyed and string-keyed input produce identical output.
    module DerivationHash
      module_function

      def compute(premises:, inference_rule:, conclusion:)
        canonical = JSON.generate(
          premises: normalized_premises(premises),
          inference_rule:,
          conclusion: stringify_keys(conclusion).sort.to_h
        )
        Digest::SHA256.hexdigest(canonical)
      end

      def normalized_premises(premises)
        premises
          .map { |p| stringify_keys(p.respond_to?(:to_h) ? p.to_h : p) }
          .sort_by { |p| [p["type"], p["source"]] }
      end

      def stringify_keys(hash)
        hash.transform_keys(&:to_s)
      end
    end
  end
end
