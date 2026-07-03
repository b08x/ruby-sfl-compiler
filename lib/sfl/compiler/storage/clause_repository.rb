# frozen_string_literal: true

require "sequel"
require "circuit_breaker"
require "journald/logger"

module SFL
  module Compiler
    # Clause repository — CRUD for annotated clauses with payload separation.
    class ClauseRepository
      CLAUSE_LISTING_COLUMNS = [
        Sequel[:clauses][:external_id].as(:id),
        Sequel[:clauses][:text],
        Sequel[:clauses][:document_id],
        Sequel[:clauses][:source_type],
        Sequel[:clauses][:topic_id],
        Sequel[:clauses][:topic_label],
        Sequel[:ideational_payloads][:process_type],
        Sequel[:ideational_payloads][:participants],
        Sequel[:ideational_payloads][:circumstances],
        Sequel[:interpersonal_payloads][:mood],
        Sequel[:interpersonal_payloads][:modality_weight],
        Sequel[:interpersonal_payloads][:tenor],
        Sequel[:interpersonal_payloads][:speaker_attitude],
        Sequel[:interpersonal_payloads][:annotation_source],
      ].freeze

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
      # @param source_type [String, nil] provenance tag (e.g. "chat_native",
      #   "chat_claude", "vault_markdown", "vault_pdf", "api") distinguishing
      #   which ingest path produced this clause — nil stores the column's
      #   own "unspecified" default rather than a Ruby-side literal, so a
      #   schema-level rename only has to happen in one place.
      # @return [String] The stored clause external_id
      def store(annotated, topic: nil, source_type: nil)
        @db.transaction do
          # Store base clause
          insert = {
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
          }
          insert[:source_type] = source_type if source_type
          @db[:clauses].insert(insert)

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
            annotation_source: annotated.interpersonal.annotation_source,
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

      # Scalar filter => how to apply it against the joined scope. Each
      # value is a 1-arity proc: given the raw filter value, returns
      # something #where can consume (a Hash-style equality condition or
      # a block-friendly Sequel expression). Table-qualified throughout
      # since both payload tables are joined into the same query.
      FIND_ALL_FILTERS = {
        document_id: ->(v) { { Sequel[:clauses][:document_id] => v } },
        source_type: ->(v) { { Sequel[:clauses][:source_type] => v } },
        annotation_source: ->(v) { { Sequel[:interpersonal_payloads][:annotation_source] => v } },
        mood: ->(v) { { Sequel[:interpersonal_payloads][:mood] => v } },
        process_type: ->(v) { { Sequel[:ideational_payloads][:process_type] => v } },
        min_modality: ->(v) { Sequel[:interpersonal_payloads][:modality_weight] >= v },
        max_modality: ->(v) { Sequel[:interpersonal_payloads][:modality_weight] <= v },
        min_tenor: ->(v) { Sequel[:interpersonal_payloads][:tenor] >= v },
        max_tenor: ->(v) { Sequel[:interpersonal_payloads][:tenor] <= v },
      }.freeze

      # Paginated, multi-filter clause listing for the Corpus Browser —
      # unlike HybridRetriever#retrieve (a ranked search result over a
      # query string), this is a plain filtered scan with no ranking, for
      # browsing a document's clauses page by page. Joins both payload
      # tables in one query (verified against a real DB before writing
      # this — Sequel's join-condition hash needs each new table's join
      # explicitly qualified against Sequel[:clauses][:external_id],
      # otherwise "clause_id"/"external_id" are ambiguous once two
      # payload tables are both in the FROM clause).
      #
      # @param filters [Hash] any of FIND_ALL_FILTERS.keys => value
      # @param limit [Integer]
      # @param offset [Integer]
      # @return [Hash] { clauses: Array<Hash>, total: Integer }
      def find_all(filters: {}, limit: 50, offset: 0)
        scope = filtered_scope(filters)

        total = scope.count
        rows = scope
          .order(Sequel[:clauses][:created_at])
          .limit(limit, offset)
          .select(*CLAUSE_LISTING_COLUMNS)
          .all

        { clauses: rows, total: }
      end

      private def filtered_scope(filters)
        scope = @db[:clauses]
          .join(:ideational_payloads, clause_id: Sequel[:clauses][:external_id])
          .join(:interpersonal_payloads, clause_id: Sequel[:clauses][:external_id])

        filters.each do |key, value|
          build = FIND_ALL_FILTERS[key]
          next unless build && value

          scope = scope.where(build.call(value))
        end

        scope
      end
    end
  end
end
