# frozen_string_literal: true

require "securerandom"

module SFL
  module Compiler
    # Persists Axiomatic summaries produced by IntermediateGenieJob.
    #
    # Each record captures the compressed SFL profile (metadata aggregates)
    # and a Genie-generated prose summary for a window of AnnotatedClauses.
    # The summary_id advances through the rolling synthesis cycle as the new
    # axiomatic base, while the original clauses remain in `clauses`.
    class AxiomaticSummaryRepository
      TABLE = :axiomatic_summaries

      def initialize(db)
        @db = db
      end

      # Store a new Axiomatic summary and return the full record.
      #
      # @return [Hash] the stored row with its generated :id
      def store(workflow_id:, source_clause_ids:, summary_text:, core_claim: nil,
                process_type_distribution: {}, avg_tenor: 0.5, avg_modality: 0.5,
                mood_distribution: {}, key_participants: [], clause_count: 0, **)
        id = SecureRandom.uuid
        @db[TABLE].insert(
          id:,
          workflow_id: workflow_id.to_s,
          source_clause_ids: Sequel.pg_jsonb(Array(source_clause_ids)),
          summary_text: summary_text.to_s,
          core_claim: core_claim.to_s,
          process_type_distribution: Sequel.pg_jsonb(process_type_distribution),
          avg_tenor: avg_tenor.to_f,
          avg_modality: avg_modality.to_f,
          mood_distribution: Sequel.pg_jsonb(mood_distribution),
          key_participants: Sequel.pg_jsonb(Array(key_participants)),
          clause_count: clause_count.to_i,
          created_at: Time.now
        )
        find(id)
      end

      # @param id [String] UUID
      # @return [Hash, nil]
      def find(id)
        @db[TABLE].where(id:).first
      end

      # All summaries for a workflow in creation order.
      # @return [Array<Hash>]
      def for_workflow(workflow_id)
        @db[TABLE].where(workflow_id: workflow_id.to_s).order(:created_at).all
      end

      # Most recent summary for a workflow.
      # @return [Hash, nil]
      def latest_for_workflow(workflow_id)
        @db[TABLE].where(workflow_id: workflow_id.to_s).order(Sequel.desc(:created_at)).first
      end
    end
  end
end
