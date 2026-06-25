# frozen_string_literal: true

# Same rationale as conversation_analysis_workflow.rb's file-top comment:
# subclassing Gush::Workflow needs the constant loaded before Zeitwerk
# autoloads this file.
require "gush"

module SFL
  module Compiler
    # Sequential four-stage sprint: Achilles proposes, Tortoise challenges,
    # Crab pins invariants, Genie synthesizes. `domain_payload` is the only
    # per-track customization point — signature classes, LM provider
    # strings, invariants, and the seed input. No domain track defines its
    # own Workflow class; they all configure this one.
    #
    # domain_payload keys:
    #   input:                seed input Hash for Achilles's signature
    #   propose_signature:    Achilles's DSPy::Signature class name (String)
    #   challenge_signature:  Tortoise's DSPy::Signature class name
    #   synthesize_signature: Genie's DSPy::Signature class name
    #   achilles_lm/tortoise_lm/genie_lm: DSPy::LM provider strings — must
    #     not all be identical (see the narrative track's RLHF-category-
    #     error rationale); this class doesn't enforce that itself, callers
    #     building a domain_payload do.
    #   invariants:           CrabConstraintJob's data-shaped rules
    #     ([{name:, field:, op:, value:}, ...]), defaults to []
    #   claims_field:         optional, defaults to "claims" in
    #     CrabConstraintJob
    #   tortoise_prior_output_key/genie_prior_output_key: optional, default
    #     "prior_output" — the input key each role's signature reads the
    #     previous stage's output from (see SprintRoleJob)
    class SprintWorkflow < Gush::Workflow
      def configure(domain_payload)
        achilles = run SprintRoleJob, params: {
          role: :achilles,
          signature_class: domain_payload.fetch(:propose_signature),
          lm: domain_payload.fetch(:achilles_lm),
          input: domain_payload.fetch(:input, {}),
        }

        tortoise = run SprintRoleJob, params: {
          role: :tortoise,
          signature_class: domain_payload.fetch(:challenge_signature),
          lm: domain_payload.fetch(:tortoise_lm),
          prior_output_key: domain_payload.fetch(:tortoise_prior_output_key, "prior_output"),
        }, after: [achilles]

        crab = run CrabConstraintJob, params: {
          invariants: domain_payload.fetch(:invariants, []),
          claims_field: domain_payload.fetch(:claims_field, "claims"),
        }, after: [tortoise]

        run SprintRoleJob, params: {
          role: :genie,
          signature_class: domain_payload.fetch(:synthesize_signature),
          lm: domain_payload.fetch(:genie_lm),
          prior_output_key: domain_payload.fetch(:genie_prior_output_key, "prior_output"),
        }, after: [crab]
      end
    end
  end
end
