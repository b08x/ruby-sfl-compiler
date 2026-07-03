# frozen_string_literal: true

require "sequel"
require "pgvector"
require "journald/logger"

module SFL
  module Compiler
    # Database connection manager.
    module Database
      # :pool_class => :timed_queue plus the fiber_concurrency extension are
      # both required for correctness under the Falcon API server. Falcon
      # runs concurrent requests as Async fibers within a single thread.
      # Sequel's default pool checks out connections keyed on
      # Sequel.current, which defaults to Thread.current — so without
      # fiber_concurrency, #hold treats two sibling fibers on the same
      # thread as "the same caller" (its re-entrant-hold fast path) and
      # hands them the SAME pg connection, even with a fiber-capable pool
      # class selected. Two concurrent requests would then interleave
      # queries on one socket, surfacing as garbled NoMethodErrors deep in
      # the pg/Sequel adapter (`undefined method 'nfields' for nil`,
      # `undefined method '<' for nil`). Loading fiber_concurrency makes
      # Sequel.current key on Fiber.current instead, so each fiber gets its
      # own connection from the (still thread-safe) TimedQueueConnectionPool.
      Sequel.extension :fiber_concurrency

      def self.connect(url = nil)
        url ||= SFL::Compiler.config.database_url
        db = Sequel.connect(url, pool_class: :timed_queue)

        # Enable pg_json extension (supports jsonb)
        db.extension :pg_json

        db
      end

      def self.setup_extensions(db)
        db.execute("CREATE EXTENSION IF NOT EXISTS vector")
        db.execute("CREATE EXTENSION IF NOT EXISTS pg_trgm")
      rescue Sequel::DatabaseError => e
        SFL::Compiler.logger.send_message(
          message: "extension_setup_failed",
          priority: Journald::LOG_WARNING,
          error: e.message
        )
      end
    end

    # Database migration runner
    class Migrator
      def initialize(db)
        @db = db
        @logger = Journald::Logger.new("sfl-compiler-migrator")
      end

      def run_all
        create_clauses_table
        create_ideational_table
        create_interpersonal_table
        create_embeddings_table
        create_question_edges_table
        create_axiomatic_summaries_table
        create_annotation_reviews_table
        backfill_columns
        create_indices
        @logger.send_message(
          message: "migrations_completed",
          priority: Journald::LOG_INFO
        )
      end

      private def create_clauses_table
        @db.create_table?(:clauses) do
          primary_key :id
          String :external_id, null: false
          String :text, null: false, text: true
          String :document_id
          Integer :sentence_index
          column :tokens, :jsonb, default: "[]"
          column :root_token, :jsonb
          Integer :topic_id
          String :topic_label
          DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

          index :external_id, unique: true
          index :document_id
          index Sequel.function(:to_tsvector, "simple", :text),
            type: :gin, name: :idx_clauses_tsv
        end
      end

      private def backfill_columns
        ColumnBackfill.new(@db).call(
          clauses: {
            topic_id: Integer, topic_label: String,
            source_type: [String, { default: "unspecified", null: false }]
          },
          interpersonal_payloads: {
            annotation_source: [String, { default: "llm", null: false }],
            # Structured evidence (premises/inference_rule/confidence) for
            # the HITL review queue — nullable, since fallback/stub/human
            # values carry no derivation to show. See
            # ClauseRepository#reconstruct_reasoning_trace.
            reasoning_trace: :jsonb
          }
        )
      end

      private def create_ideational_table
        @db.create_table?(:ideational_payloads) do
          primary_key :id
          String :clause_id, null: false
          String :process_type, null: false
          column :participants, :jsonb, default: "[]"
          column :circumstances, :jsonb, default: "[]"
          column :raw_transitivity, :jsonb, default: "{}"
          DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

          index :clause_id, unique: true
          index :process_type
        end
      end

      private def create_interpersonal_table
        @db.create_table?(:interpersonal_payloads) do
          primary_key :id
          String :clause_id, null: false
          String :mood, null: false
          Float :modality_weight, null: false, default: 0.5
          Float :tenor, null: false, default: 0.5
          String :speaker_attitude
          String :reasoning
          String :annotation_source, null: false, default: "llm"
          DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

          index :clause_id, unique: true
          index :modality_weight
          index :tenor
          index :mood
        end
      end

      private def create_embeddings_table
        @db.create_table?(:embeddings) do
          primary_key :id
          String :clause_id, null: false
          column :embedding, "vector(768)" # Ollama embeddinggemma:latest
          String :model, null: false, default: "embeddinggemma:latest"
          DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

          index %i[clause_id model], unique: true
          index :embedding, type: :ivfflat, opclass: :vector_cosine_ops
        end
      end

      private def create_question_edges_table
        @db.create_table?(:question_edges) do
          primary_key :id
          String :parent_id, null: false
          String :child_id,  null: false
          Integer :depth,    null: false, default: 0
          DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

          index [:parent_id, :child_id], unique: true, name: :idx_question_edges_pair
          index :child_id, name: :idx_question_edges_child
        end
      end

      private def create_axiomatic_summaries_table
        @db.create_table?(:axiomatic_summaries) do
          String :id, primary_key: true  # UUID
          String :workflow_id, null: false, default: "standalone"
          column :source_clause_ids, :jsonb, default: "[]"
          String :summary_text, text: true, null: false
          String :core_claim, text: true
          column :process_type_distribution, :jsonb, default: "{}"
          Float :avg_tenor, default: 0.5
          Float :avg_modality, default: 0.5
          column :mood_distribution, :jsonb, default: "{}"
          column :key_participants, :jsonb, default: "[]"
          Integer :clause_count, default: 0
          DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

          index :workflow_id, name: :idx_axiomatic_summaries_workflow
          index :created_at, name: :idx_axiomatic_summaries_created_at
        end
      end

      # Append-only audit trail for human review decisions (Types::AnnotationReview).
      # No FK to clauses.external_id — same convention as ideational/interpersonal
      # payloads, which key on the plain clause_id string rather than a real FK.
      private def create_annotation_reviews_table
        @db.create_table?(:annotation_reviews) do
          String :id, primary_key: true  # UUID
          String :clause_id, null: false
          String :decision, null: false
          String :original_annotation_source, null: false
          String :reviewer
          String :notes, text: true
          DateTime :reviewed_at, null: false, default: Sequel::CURRENT_TIMESTAMP
          DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

          index :clause_id, name: :idx_annotation_reviews_clause_id
        end
      end

      private def create_indices
        # Composite index for scalar filtering + vector search
        @db.execute(<<~SQL)
          CREATE INDEX IF NOT EXISTS idx_interpersonal_scalar_filter
          ON interpersonal_payloads (mood, modality_weight, tenor)
        SQL

        # Full-text search index
        @db.execute(<<~SQL)
          CREATE INDEX IF NOT EXISTS idx_clauses_gin_tokens
          ON clauses USING gin (tokens)
        SQL

        # source_type is backfilled (see #backfill_columns), so this index
        # is created separately rather than inline on create_table? —
        # IF NOT EXISTS makes it safe to run before or after the backfill.
        @db.execute(<<~SQL)
          CREATE INDEX IF NOT EXISTS idx_clauses_source_type
          ON clauses (source_type)
        SQL
      rescue Sequel::DatabaseError => e
        @logger.send_message(
          message: "index_creation_failed",
          priority: Journald::LOG_WARNING,
          error: e.message
        )
      end
    end

    # Adds columns introduced after a table's first release to databases
    # migrated before they existed (create_table? is a no-op against an
    # already-existing table, so Migrator can't reach them that way).
    class ColumnBackfill
      def initialize(db)
        @db = db
      end

      # @param table_columns [Hash{Symbol => Hash{Symbol => Class, Array}}]
      #   table name => { column name => type, or [type, options] }
      def call(table_columns)
        table_columns.each { |table, columns| backfill_table(table, columns) }
      end

      private def backfill_table(table, columns)
        existing = @db.schema(table).map(&:first)
        columns.each do |name, spec|
          next if existing.include?(name)

          type, opts = spec.is_a?(Array) ? spec : [spec, {}]
          @db.add_column(table, name, type, **opts)
        end
      end
    end
  end
end
