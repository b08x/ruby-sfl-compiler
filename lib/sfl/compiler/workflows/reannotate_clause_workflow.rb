# frozen_string_literal: true

# Same rationale as ConversationAnalysisWorkflow's file-top comment:
# subclassing Gush::Workflow needs the constant loaded before Zeitwerk
# autoloads this file.
require "gush"

module SFL
  module Compiler
    # Single-job workflow wrapping ReannotateClauseJob. Gush has no bare
    # "enqueue one job" API — every dispatch is a Workflow, even a
    # trivial one-node DAG — so this exists purely to give the "re-
    # annotate" decision handler (Review queue surface card) something
    # to call: ReannotateClauseWorkflow.create(clause_id:, reviewer:,
    # notes:); flow.start!; flow.reload; flow.status, same shape as
    # ConversationAnalysisWorkflow.
    class ReannotateClauseWorkflow < Gush::Workflow
      def configure(clause_id:, reviewer: nil, notes: nil)
        run ReannotateClauseJob, params: { clause_id:, reviewer:, notes: }
      end
    end
  end
end
