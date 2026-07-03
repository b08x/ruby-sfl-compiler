# frozen_string_literal: true

# Same rationale as CompileTurnJob's file-top comment: subclassing
# Gush::Job needs the constant loaded before Zeitwerk autoloads this file.
require "gush"

module SFL
  module Compiler
    # Re-runs Pass 2 for one flagged clause, triggered by a human
    # "re-annotate" decision (Human-in-the-Loop Annotation Review track).
    # Runs in its own Sidekiq worker process rather than wherever the
    # decision was made (TUI/API) — Pass 2 is LLM-only and never touches
    # PyCall, so it *could* run inline, but the job+poll process model is
    # kept consistent with every other pipeline stage rather than special-
    # casing this one for the shortcut.
    #
    # Bypasses PipelineCache entirely by construction: that cache is only
    # ever consulted inside Pipeline#compile's resume path, and this job
    # calls PassTwoEngine#annotate directly against Pass 1 output
    # reconstructed from the database — no Pipeline instance involved, so
    # there is no cache lookup to bypass in the first place.
    #
    # annotation_source on the resulting clause is whatever PassTwoEngine
    # itself sets (llm on success, fallback on failure) — NOT forced to
    # "human". A human triggered the recompile, but the values are still
    # machine-produced; "human" is reserved for values a person actually
    # supplied. The annotation_reviews row (decision: "re_annotated")
    # is the durable record that a human acted here.
    class ReannotateClauseJob < Gush::Job
      def perform
        clause_id = params.fetch(:clause_id)
        pass_one = clause_repo.find_pass_one_output(clause_id)
        raise ArgumentError, "clause #{clause_id}: not found or missing Pass 1 output" unless pass_one

        annotated = pass_two.annotate(pass_one[:syntactic], pass_one[:ideational])
        clause_repo.update_interpersonal(clause_id, annotated.interpersonal)
        record_review(clause_id)

        output(Types.dump(annotated))
      end

      private def record_review(clause_id)
        original_source = clause_repo.find(clause_id)&.dig(:interpersonal, :annotation_source) || "llm"
        clause_repo.record_review(
          clause_id:, decision: "re_annotated", original_annotation_source: original_source,
          reviewer: params[:reviewer], notes: params[:notes]
        )
      end

      private def clause_repo
        @clause_repo ||= ClauseRepository.new(bootstrap_ctx.db)
      end

      private def pass_two
        @pass_two ||= PassTwoEngine.new
      end

      private def bootstrap_ctx
        @bootstrap_ctx ||= Bootstrap.call(require_db: true, require_llm: true, require_observability: true)
      end
    end
  end
end
