# frozen_string_literal: true

require "sequel"
require "pgvector"
require "journald/logger"

module SFL
  module Compiler
    # Database connection manager.
    module Database
      def self.connect(url = nil)
        url ||= SFL::Compiler.config.database_url
        db = Sequel.connect(url)

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
        create_indices
        add_clause_topic_columns
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

      # `create_table?` is a no-op against an already-existing `clauses`
      # table (the topic columns above only apply on a fresh install), so
      # add them here too for databases migrated before topic tagging existed.
      private def add_clause_topic_columns
        existing = @db.schema(:clauses).map(&:first)
        @db.add_column(:clauses, :topic_id, Integer) unless existing.include?(:topic_id)
        @db.add_column(:clauses, :topic_label, String) unless existing.include?(:topic_label)
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
      rescue Sequel::DatabaseError => e
        @logger.send_message(
          message: "index_creation_failed",
          priority: Journald::LOG_WARNING,
          error: e.message
        )
      end
    end
  end
end
