# frozen_string_literal: true

require "circuit_breaker"
require "journald/logger"
require "pgvector"

module SFL
  module Compiler
    # Hybrid Retriever with Reciprocal Rank Fusion (RRF).
    #
    # Combines semantic vector search with keyword full-text search
    # and scalar metadata filtering on Interpersonal features.
    #
    # RRF formula: score(d) = Σ 1/(60 + rank_i(d)) for each list i
    class HybridRetriever
      RRF_K = 60 # Standard RRF constant

      def initialize(db:, embedder: nil)
        @db = db
        @embedder = embedder
        @logger = Journald::Logger.new("sfl-compiler-retriever")
      end

      # Main retrieval entry point.
      #
      # @param query [String] Natural language query
      # @param limit [Integer] Number of results
      # @param filters [Hash] Scalar filters:
      #   - :mood [String] Mood type filter
      #   - :min_modality [Float] Minimum modality weight
      #   - :max_modality [Float] Maximum modality weight
      #   - :min_tenor [Float] Minimum formality
      #   - :max_tenor [Float] Maximum formality
      #   - :process_type [String] Ideational process type filter
      #   - :source_type [String] Provenance filter (e.g. "chat_native",
      #     "vault_markdown") — see ClauseRepository#store
      # @return [Array<Hash>] Ranked results with scores
      def retrieve(query, limit: 10, filters: {})
        start_time = Time.now
        correlation_id = SecureRandom.uuid

        @logger.send_message(
          message: "retrieval_started",
          priority: Journald::LOG_INFO,
          correlation_id:,
          query: query[0..100],
          filters:,
          limit:
        )

        # Pass 1: Semantic search (vector similarity)
        semantic_results = semantic_search(query, limit: limit * 3)

        # Pass 2: Keyword search (full-text)
        keyword_results = keyword_search(query, limit: limit * 3)

        # Merge with RRF
        merged = reciprocal_rank_fusion(semantic_results, keyword_results)

        # Apply scalar metadata filters
        filtered = apply_filters(merged, filters)

        # Limit results
        results = filtered.first(limit)

        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "retrieval_completed",
          priority: Journald::LOG_INFO,
          correlation_id:,
          semantic_count: semantic_results.length,
          keyword_count: keyword_results.length,
          merged_count: merged.length,
          filtered_count: results.length,
          latency_ms: elapsed_ms
        )

        results
      end

      private def semantic_search(query, limit:)
        return [] unless @embedder

        query_embedding = @embedder.embed(query)
        return [] unless query_embedding

        vector = Pgvector.encode(query_embedding)

        @db[:embeddings]
          .join(:clauses, external_id: :clause_id)
          .order(Sequel.lit("embedding <=> ?", vector))
          .limit(limit)
          .select(
            Sequel[:clauses][:external_id].as(:clause_id),
            Sequel[:clauses][:text],
            Sequel[:clauses][:document_id],
            Sequel.lit("1 - (embedding <=> ?) AS similarity_score", vector)
          )
          .to_a.each_with_index.map do |row, idx|
            row.merge(semantic_rank: idx + 1)
          end
      rescue => e
        @logger.send_message(
          message: "semantic_search_failed",
          priority: Journald::LOG_WARNING,
          error: e.message
        )
        []
      end

      private def keyword_search(query, limit:)
        @db[:clauses]
          .where(
            Sequel.lit(
              "to_tsvector('simple', text) @@ plainto_tsquery('simple', ?)",
              query
            )
          )
          .order(
            Sequel.lit(
              "ts_rank(to_tsvector('simple', text), plainto_tsquery('simple', ?)) DESC",
              query
            )
          )
          .limit(limit)
          .select(
            Sequel[:clauses][:external_id].as(:clause_id),
            Sequel[:clauses][:text],
            Sequel[:clauses][:document_id]
          )
          .to_a.each_with_index.map do |row, idx|
            row.merge(keyword_rank: idx + 1)
          end
      rescue => e
        @logger.send_message(
          message: "keyword_search_failed",
          priority: Journald::LOG_WARNING,
          error: e.message
        )
        []
      end

      private def reciprocal_rank_fusion(semantic_results, keyword_results)
        scores = Hash.new { |h, k| h[k] = { rrf_score: 0.0, data: {} } }

        semantic_results.each do |row|
          cid = row[:clause_id]
          rank = row[:semantic_rank]
          scores[cid][:rrf_score] += 1.0 / (RRF_K + rank)
          scores[cid][:data].merge!(row)
        end

        keyword_results.each do |row|
          cid = row[:clause_id]
          rank = row[:keyword_rank]
          scores[cid][:rrf_score] += 1.0 / (RRF_K + rank)
          scores[cid][:data].merge!(row)
        end

        scores.map do |_, v|
          v[:data].merge(rrf_score: v[:rrf_score].round(6))
        end.sort_by { |r| -r[:rrf_score] }
      end

      private def apply_filters(results, filters)
        return results if filters.empty?

        clause_ids = results.map { |r| r[:clause_id] }

        # Pre-fetch payloads to avoid N+1 queries
        interpersonal_map = @db[:interpersonal_payloads]
          .where(clause_id: clause_ids)
          .as_hash(:clause_id)

        ideational_map = @db[:ideational_payloads]
          .where(clause_id: clause_ids)
          .as_hash(:clause_id)

        # source_type lives on clauses itself (external_id), not a
        # separate payload table.
        source_type_map = @db[:clauses]
          .where(external_id: clause_ids)
          .as_hash(:external_id, :source_type)

        results.select do |row|
          clause_id = row[:clause_id]
          interpersonal = interpersonal_map[clause_id]
          ideational = ideational_map[clause_id]

          next false unless interpersonal

          next false if filters[:mood] && interpersonal[:mood] != filters[:mood]

          next false if filters[:min_modality] && interpersonal[:modality_weight] < filters[:min_modality]

          next false if filters[:max_modality] && interpersonal[:modality_weight] > filters[:max_modality]

          next false if filters[:min_tenor] && interpersonal[:tenor] < filters[:min_tenor]

          next false if filters[:max_tenor] && interpersonal[:tenor] > filters[:max_tenor]

          next false if filters[:process_type] && ideational && ideational[:process_type] != filters[:process_type]

          next false if filters[:source_type] && source_type_map[clause_id] != filters[:source_type]

          true
        end
      end
    end
  end
end
