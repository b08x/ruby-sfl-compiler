# frozen_string_literal: true

require "sequel"
require "circuit_breaker"
require "journald/logger"

module SFL
  module Compiler
    # Clause repository — CRUD for annotated clauses with payload separation.
    class ClauseRepository
      def initialize(db)
        @db = db
        @logger = Journald::Logger.new("sfl-compiler-repo")
      end

      # Store a fully annotated clause with separated payloads.
      #
      # @param annotated [Types::AnnotatedClause]
      # @param topic [Hash, nil] { id:, label: } from a pre-pass TopicModeler
      #   fit over the clause's document/section — nil when topic modeling
      #   wasn't requested.
      # @return [String] The stored clause external_id
      def store(annotated, topic: nil)
        @db.transaction do
          # Store base clause
          @db[:clauses].insert(
            external_id: annotated.id,
            text: annotated.text,
            document_id: annotated.document_id,
            sentence_index: annotated.syntactic.sentence_index,
            tokens: Sequel.pg_jsonb(annotated.syntactic.tokens.map(&:to_h)),
            root_token: Sequel.pg_jsonb(
              annotated.syntactic.tokens[annotated.syntactic.root_index].to_h
            ),
            topic_id: topic&.fetch(:id, nil),
            topic_label: topic&.fetch(:label, nil),
            created_at: Time.now
          )

          # Store Ideational payload (from Pass 1)
          @db[:ideational_payloads].insert(
            clause_id: annotated.id,
            process_type: annotated.ideational.process_type,
            participants: Sequel.pg_jsonb(annotated.ideational.participants.map(&:to_h)),
            circumstances: Sequel.pg_jsonb(annotated.ideational.circumstances),
            raw_transitivity: Sequel.pg_jsonb(annotated.ideational.raw_transitivity),
            created_at: Time.now
          )

          # Store Interpersonal payload (from Pass 2)
          @db[:interpersonal_payloads].insert(
            clause_id: annotated.id,
            mood: annotated.interpersonal.mood,
            modality_weight: annotated.interpersonal.modality_weight,
            tenor: annotated.interpersonal.tenor,
            speaker_attitude: annotated.interpersonal.speaker_attitude,
            reasoning: annotated.interpersonal.reasoning,
            created_at: Time.now
          )
        end

        @logger.send_message(
          message: "clause_stored",
          priority: Journald::LOG_INFO,
          clause_id: annotated.id,
          document_id: annotated.document_id,
          process_type: annotated.ideational.process_type,
          mood: annotated.interpersonal.mood
        )

        annotated.id
      rescue Sequel::DatabaseError => e
        @logger.send_message(
          message: "clause_store_failed",
          priority: Journald::LOG_ERR,
          clause_id: annotated.id,
          error: e.message
        )
        raise
      end

      # Remove every clause (and its payload/embedding rows) previously
      # stored for a document. Clause external_ids are fresh UUIDs on every
      # compile, so re-ingesting without this silently duplicates content;
      # callers delete-then-store to make ingestion idempotent per document.
      #
      # @param document_id [String]
      # @return [Integer] number of clauses removed
      def delete_by_document(document_id)
        @db.transaction do
          scoped = @db[:clauses].where(document_id:)
          clause_ids = scoped.select_map(:external_id)
          break 0 if clause_ids.empty?

          @db[:ideational_payloads].where(clause_id: clause_ids).delete
          @db[:interpersonal_payloads].where(clause_id: clause_ids).delete
          @db[:embeddings].where(clause_id: clause_ids).delete
          scoped.delete
        end
      end

      # Retrieve an annotated clause by ID with all payloads.
      #
      # @param clause_id [String]
      # @return [Hash, nil]
      def find(clause_id)
        clause = @db[:clauses].where(external_id: clause_id).first
        return nil unless clause

        ideational = @db[:ideational_payloads].where(clause_id:).first
        interpersonal = @db[:interpersonal_payloads].where(clause_id:).first
        embedding = @db[:embeddings].where(clause_id:).first

        {
          clause:,
          ideational:,
          interpersonal:,
          embedding:,
        }
      end

      # Find clauses by scalar interpersonal filters.
      #
      # @param mood [String, nil] Filter by mood type
      # @param min_modality [Float, nil] Minimum modality weight
      # @param max_modality [Float, nil] Maximum modality weight
      # @param min_tenor [Float, nil] Minimum tenor (formality)
      # @param max_tenor [Float, nil] Maximum tenor
      # @param limit [Integer] Max results
      # @return [Array<Hash>]
      def find_by_interpersonal(
        mood: nil,
        min_modality: nil, max_modality: nil,
        min_tenor: nil, max_tenor: nil,
        limit: 50
      )
        ds = @db[:clauses]
          .join(:interpersonal_payloads, clause_id: :external_id)

        ds = ds.where(mood:) if mood
        ds = ds.where { modality_weight >= min_modality } if min_modality
        ds = ds.where { modality_weight <= max_modality } if max_modality
        ds = ds.where { tenor >= min_tenor } if min_tenor
        ds = ds.where { tenor <= max_tenor } if max_tenor

        ds.limit(limit).all
      end

      # Find clauses by Ideational process type.
      #
      # @param process_type [String] One of: material, mental, relational, verbal, behavioral, existential
      # @param limit [Integer]
      # @return [Array<Hash>]
      def find_by_process_type(process_type, limit: 50)
        @db[:clauses]
          .join(:ideational_payloads, clause_id: :external_id)
          .where(process_type:)
          .limit(limit)
          .all
      end
    end
  end
end
