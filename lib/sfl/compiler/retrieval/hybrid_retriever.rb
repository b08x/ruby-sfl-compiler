# frozen_string_literal: true

require "circuit_breaker"
require "journald/logger"

module SFL
  module Compiler
    # Hybrid Retriever with Reciprocal Rank Fusion (RRF).
    #
    # Combines semantic vector search with keyword full-text search
    # and scalar metadata filtering on Interpersonal features.
    #
    # RRF formula: score(d) = Σ 1/(60 + rank_i(d)) for each list i
    class HybridRetriever
      RRF_K = 60  # Standard RRF constant

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
      # @return [Array<Hash>] Ranked results with scores
      def retrieve(query, limit: 10, filters: {})
        start_time = Time.now
        correlation_id = SecureRandom.uuid

        @logger.send_message(
          message: "retrieval_started",
          priority: Journald::LOG_INFO,
          correlation_id: correlation_id,
          query: query[0..100],
          filters: filters,
          limit: limit
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
          correlation_id: correlation_id,
          semantic_count: semantic_results.length,
          keyword_count: keyword_results.length,
          merged_count: merged.length,
          filtered_count: results.length,
          latency_ms: elapsed_ms
        )

        results
      end

      private

      def semantic_search(query, limit:)
        return [] unless @embedder

        query_embedding = @embedder.embed(query)
        return [] unless query_embedding

        @db[:embeddings]
          .join(:clauses, external_id: :clause_id)
          .order(Sequel.lit("embedding <=> ?", query_embedding))
          .limit(limit)
          .select(
            Sequel[:clauses][:external_id].as(:clause_id),
            Sequel[:clauses][:text],
            Sequel[:clauses][:document_id],
            Sequel.lit("1 - (embedding <=> ?) AS similarity_score", query_embedding)
          )
          .map_with_index { |row, idx|
            row.merge(semantic_rank: idx + 1)
          }
      rescue StandardError => e
        @logger.send_message(
          message: "semantic_search_failed",
          priority: Journald::LOG_WARNING,
          error: e.message
        )
        []
      end

      def keyword_search(query, limit:)
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
          .map_with_index { |row, idx|
            row.merge(keyword_rank: idx + 1)
          }
      rescue StandardError => e
        @logger.send_message(
          message: "keyword_search_failed",
          priority: Journald::LOG_WARNING,
          error: e.message
        )
        []
      end

      def reciprocal_rank_fusion(semantic_results, keyword_results)
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

        scores.map { |_, v|
          v[:data].merge(rrf_score: v[:rrf_score].round(6))
        }.sort_by { |r| -r[:rrf_score] }
      end

      def apply_filters(results, filters)
        return results if filters.empty?

        clause_ids = results.map { |r| r[:clause_id] }
        
        # Pre-fetch payloads to avoid N+1 queries
        interpersonal_map = @db[:interpersonal_payloads]
                            .where(clause_id: clause_ids)
                            .as_hash(:clause_id)
        
        ideational_map = @db[:ideational_payloads]
                         .where(clause_id: clause_ids)
                         .as_hash(:clause_id)

        results.select do |row|
          clause_id = row[:clause_id]
          interpersonal = interpersonal_map[clause_id]
          ideational = ideational_map[clause_id]

          next false unless interpersonal

          if filters[:mood] && interpersonal[:mood] != filters[:mood]
            next false
          end

          if filters[:min_modality] && interpersonal[:modality_weight] < filters[:min_modality]
            next false
          end

          if filters[:max_modality] && interpersonal[:modality_weight] > filters[:max_modality]
            next false
          end

          if filters[:min_tenor] && interpersonal[:tenor] < filters[:min_tenor]
            next false
          end

          if filters[:max_tenor] && interpersonal[:tenor] > filters[:max_tenor]
            next false
          end

          if filters[:process_type] && ideational && ideational[:process_type] != filters[:process_type]
            next false
          end

          true
        end
      end
    end

    # Simple embedding interface compatible with HybridRetriever.
    # Uses ruby_llm for embedding generation.
    class Embedder
      include CircuitBreaker

      def initialize(model: "text-embedding-ada-002")
        @model = model
        @logger = Journald::Logger.new("sfl-compiler-embedder")
      end

      # Generate embedding vector for text.
      #
      # @param text [String]
      # @return [Array<Float>, nil]
      def embed(text)
        return nil if text.nil? || text.strip.empty?

        call_ruby_llm(text)
      rescue CircuitBreaker::CircuitBrokenException
        @logger.send_message(
          message: "embedder_circuit_open",
          priority: Journald::LOG_WARNING
        )
        nil
      rescue StandardError => e
        @logger.send_message(
          message: "embed_failed",
          priority: Journald::LOG_ERR,
          error: e.message
        )
        nil
      end

      private

      def call_ruby_llm(text)
        response = RubyLLM.embed(text, model: @model)
        response.embedding
      end
      circuit_method :call_ruby_llm

      circuit_handler do |handler|
        handler.failure_threshold = 5
        handler.failure_timeout = 60
        handler.invocation_timeout = 30
      end
    end
  end
end
