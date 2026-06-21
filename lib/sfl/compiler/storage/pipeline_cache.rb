# frozen_string_literal: true

require "digest"
require "json"
require "fileutils"

module SFL
  module Compiler
    # PipelineCache — disk-based cache for Pass 1 + Pass 2 results.
    #
    # Enables resume functionality: if a compilation fails partway through
    # (typically during expensive Pass 2 LLM calls), cached clause results
    # from the previous run can be reused, avoiding redundant API calls.
    #
    # Cache location: `.sfl-cache/` in the working directory (configurable).
    # Key: SHA256(document_id + clause_text) — deterministic, collision-resistant.
    # Format: One JSON file per clause, containing the full AnnotatedClause hash.
    #
    # Usage:
    #   cache = PipelineCache.new
    #   cache.store(document_id, clause, annotated_clause)
    #   cached = cache.fetch(document_id, clause)
    #   cached_clauses, missing_clauses = cache.partition(pairs)
    #
    class PipelineCache
      CACHE_DIR = ".sfl-cache"

      # @param cache_dir [String] directory for cached clause files
      def initialize(cache_dir: CACHE_DIR)
        @cache_dir = cache_dir
      end

      # Fetch a cached AnnotatedClause for the given document + clause.
      #
      # @param document_id [String]
      # @param clause [Types::SyntacticClause]
      # @return [Types::AnnotatedClause, nil] nil if not cached
      def fetch(document_id, clause)
        path = cache_path(document_id, clause)
        return nil unless File.exist?(path)

        hash = JSON.parse(File.read(path), symbolize_names: true)
        reconstruct(hash)
      rescue JSON::ParserError, KeyError
        # Corrupted cache entry — treat as miss
        nil
      end

      # Store an AnnotatedClause in the cache.
      #
      # @param document_id [String]
      # @param clause [Types::SyntacticClause] the original clause (for key)
      # @param annotated [Types::AnnotatedClause] the compiled result
      def store(document_id, clause, annotated)
        path = cache_path(document_id, clause)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, JSON.pretty_generate(annotated.to_h))
      end

      # Check if a clause is already cached.
      #
      # @param document_id [String]
      # @param clause [Types::SyntacticClause]
      # @return [Boolean]
      def cached?(document_id, clause)
        File.exist?(cache_path(document_id, clause))
      end

      # Partition pairs into cached and uncached groups.
      # Returns [cached_results, uncached_pairs] where cached_results
      # are already-compiled AnnotatedClauses and uncached_pairs are
      # [SyntacticClause, IdeationalPayload] tuples needing Pass 2.
      #
      # @param document_id [String]
      # @param pairs [Array<[Types::SyntacticClause, Types::IdeationalPayload]>]
      # @return [Array(Array<Types::AnnotatedClause>, Array)>]
      def partition(document_id, pairs)
        cached = []
        uncached = []

        pairs.each do |clause, ideational|
          hit = fetch(document_id, clause)
          if hit
            cached << hit
          else
            uncached << [clause, ideational]
          end
        end

        [cached, uncached]
      end

      # Clear all cached data for a document.
      #
      # @param document_id [String]
      def clear(document_id)
        dir = document_dir(document_id)
        FileUtils.rm_rf(dir) if File.directory?(dir)
      end

      # Clear all cached data.
      def clear_all
        FileUtils.rm_rf(@cache_dir)
      end

      # Number of cached clauses for a document.
      #
      # @param document_id [String]
      # @return [Integer]
      def count(document_id)
        dir = document_dir(document_id)
        return 0 unless File.directory?(dir)

        Dir.glob(File.join(dir, "*.json")).size
      end

      private

      # Deterministic cache key: SHA256(document_id + clause_text).
      def cache_key(document_id, clause)
        Digest::SHA256.hexdigest("#{document_id}#{clause.text}")
      end

      def cache_path(document_id, clause)
        key = cache_key(document_id, clause)
        File.join(@cache_dir, document_id, "#{key}.json")
      end

      def document_dir(document_id)
        File.join(@cache_dir, document_id)
      end

      # Reconstruct an AnnotatedClause from a hash.
      # Handles nested Dry::Struct types (SyntacticClause, IdeationalPayload,
      # InterpersonalPayload, TextualPayload).
      def reconstruct(hash)
        Types::AnnotatedClause.new(
          id: hash[:id],
          text: hash[:text],
          syntactic: reconstruct_syntactic(hash[:syntactic]),
          ideational: reconstruct_ideational(hash[:ideational]),
          interpersonal: reconstruct_interpersonal(hash[:interpersonal]),
          textual: hash[:textual] ? reconstruct_textual(hash[:textual]) : nil,
          document_id: hash[:document_id],
          compiled_at: Time.parse(hash[:compiled_at])
        )
      end

      def reconstruct_syntactic(hash)
        return nil unless hash

        Types::SyntacticClause.new(
          id: hash[:id],
          text: hash[:text],
          tokens: (hash[:tokens] || []).map { |t| reconstruct_token(t) },
          root_index: hash[:root_index],
          sentence_index: hash[:sentence_index],
          document_id: hash[:document_id]
        )
      end

      def reconstruct_token(hash)
        Types::SyntacticToken.new(
          text: hash[:text],
          lemma: hash[:lemma],
          pos: hash[:pos],
          tag: hash[:tag],
          dep: hash[:dep],
          head_index: hash[:head_index],
          morphology: hash[:morphology] || {},
          index: hash[:index]
        )
      end

      def reconstruct_ideational(hash)
        return nil unless hash

        Types::IdeationalPayload.new(
          clause_id: hash[:clause_id],
          process_type: hash[:process_type],
          participants: (hash[:participants] || []).map { |p| reconstruct_participant(p) },
          circumstances: (hash[:circumstances] || []).map { |c| reconstruct_participant(c) },
          raw_transitivity: hash[:raw_transitivity]
        )
      end

      def reconstruct_participant(hash)
        Types::Participant.new(
          text: hash[:text],
          role: hash[:role],
          head: hash[:head]
        )
      end

      def reconstruct_interpersonal(hash)
        return nil unless hash

        Types::InterpersonalPayload.new(
          clause_id: hash[:clause_id],
          mood: hash[:mood],
          modality_weight: hash[:modality_weight],
          tenor: hash[:tenor],
          speaker_attitude: hash[:speaker_attitude],
          reasoning: hash[:reasoning],
          annotation_source: hash[:annotation_source] || "llm"
        )
      end

      def reconstruct_textual(hash)
        return nil unless hash

        Types::TextualPayload.new(
          clause_id: hash[:clause_id],
          topical_theme: hash[:topical_theme],
          textual_theme: hash[:textual_theme],
          interpersonal_theme: hash[:interpersonal_theme],
          rheme: hash[:rheme],
          theme_type: hash[:theme_type]
        )
      end
    end
  end
end
