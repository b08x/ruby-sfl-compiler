# frozen_string_literal: true

require "sequel"
require "journald/logger"

module SFL
  module Compiler
    # Embedding storage and management.
    class EmbeddingRepository
      def initialize(db)
        @db = db
        @logger = Journald::Logger.new("sfl-compiler-embeddings")
      end

      # Store an embedding vector for a clause.
      #
      # @param clause_id [String]
      # @param embedding [Array<Float>] 768-dim vector
      # @param model [String] Model identifier
      def store(clause_id, embedding, model: "embeddinggemma:latest")
        @db[:embeddings].insert(
          clause_id: clause_id,
          embedding: embedding,
          model: model,
          created_at: Time.now
        )
      rescue Sequel::UniqueConstraintViolation
        # Update existing embedding
        @db[:embeddings]
          .where(clause_id: clause_id, model: model)
          .update(embedding: embedding, created_at: Time.now)
      end

      # Find nearest neighbors to a query embedding.
      #
      # @param query_embedding [Array<Float>]
      # @param limit [Integer]
      # @param distance [Symbol] :cosine, :l2, :inner_product
      # @return [Array<Hash>]
      def nearest_neighbors(query_embedding, limit: 10, distance: :cosine)
        operator = case distance
                  when :cosine then "<=>"
                  when :l2 then "<->"
                  when :inner_product then "<#>"
                  else "<=>"
                  end

        @db[:embeddings]
          .join(:clauses, external_id: :clause_id)
          .order(Sequel.lit("embedding #{operator} ?", query_embedding))
          .limit(limit)
          .select(
            Sequel[:clauses][:external_id],
            Sequel[:clauses][:text],
            Sequel.lit("1 - (embedding #{operator} ?) AS similarity", query_embedding)
          )
          .all
      end
    end
  end
end
