# frozen_string_literal: true

require "journald/logger"

module SFL
  module Compiler
    # Two-Pass SFL Compiler Pipeline
    #
    # Orchestrates the full compilation pipeline:
    #   Pass 1: SyntacticEngine → IdeationalExtractor
    #   Pass 2: SemanticAnnotator (DSPy.rb)
    #   Storage: ClauseRepository + EmbeddingRepository
    #
    # Supports resume mode: when `resume: true`, cached Pass 2 results
    # from previous runs are reused, avoiding redundant LLM calls.
    #
    # Usage:
    #   pipeline = SFL::Compiler::Pipeline.new(db: db)
    #   results = pipeline.compile("Your text here", document_id: "doc-1")
    #   results = pipeline.compile("Your text here", document_id: "doc-1", resume: true)
    class Pipeline
      def initialize(db:, spacy_model: nil, embedder: nil, cache_dir: nil)
        @db = db
        @pass_one = PassOneEngine.new(model: spacy_model)
        @ideational_extractor = IdeationalExtractor.new
        @pass_two = PassTwoEngine.new
        @clause_repo = ClauseRepository.new(db)
        @embedding_repo = EmbeddingRepository.new(db)
        @embedder = embedder
        @cache = PipelineCache.new(cache_dir:) if cache_dir
        @logger = Journald::Logger.new("sfl-compiler-pipeline")
      end

      # Compile a full document through both passes.
      #
      # @param text [String] Raw text to compile
      # @param document_id [String, nil] Source document identifier
      # @param store [Boolean] Whether to persist to database
      # @param embed [Boolean] Whether to generate and store embeddings
      # @param resume [Boolean] Use cached Pass 2 results from previous runs
      # @param topic [Hash, nil] { id:, label: } from a pre-pass TopicModeler
      #   fit, attached to every clause stored from this call
      # @return [Array<Types::AnnotatedClause>]
      def compile(text, document_id: nil, store: true, embed: true, resume: false, topic: nil, semantic_coherence_score: nil, on_chunk_done: nil)
        start_time = Time.now
        correlation_id = SecureRandom.uuid

        @logger.send_message(
          message: "pipeline_started",
          priority: Journald::LOG_INFO,
          correlation_id:,
          document_id:,
          text_length: text.length,
          resume:
        )

        # === PASS 1: Syntactic Extraction ===
        syntactic_clauses = @pass_one.process(text, document_id:)

        # === PASS 1 Post-Processing: Ideational Extraction ===
        ideational_payloads = syntactic_clauses.map do |clause|
          @ideational_extractor.extract(clause)
        end

        pairs = syntactic_clauses.zip(ideational_payloads)

        # === PASS 2: Semantic Annotation (DSPy.rb, batched) ===
        # Sweep Pass 1's dead PyCall wrappers NOW, on this thread. If GC
        # instead triggers on a Pass 2 worker, pycall_pyptr_free blocks on
        # the Python GIL while holding the GVL — deadlocking the whole VM
        # (observed live: gc_sweep → PyGILState_Ensure → take_gil, with the
        # Timeout watchdog and HTTP reads frozen behind the GVL).
        GC.start

        annotated = if resume && @cache
          compile_with_cache(document_id, pairs, correlation_id, semantic_coherence_score)
        else
          @pass_two.annotate_batch(pairs,
            semantic_coherence_score: semantic_coherence_score,
            on_chunk_done: on_chunk_done)
        end

        # === Cache store after successful Pass 2 ===
        if @cache && document_id
          pairs.zip(annotated).each do |(clause, _ideational), ac|
            @cache.store(document_id, clause, ac)
          end
        end

        # === Storage ===
        if store
          annotated.each do |ac|
            @clause_repo.store(ac, topic:)
          end
        end

        # === Embedding ===
        if embed && @embedder
          annotated.each do |ac|
            embedding = @embedder.embed(ac.text)
            @embedding_repo.store(ac.id, embedding) if embedding
          end
        end

        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "pipeline_completed",
          priority: Journald::LOG_INFO,
          correlation_id:,
          document_id:,
          clause_count: annotated.length,
          stored: store,
          embedded: embed,
          resume:,
          latency_ms: elapsed_ms
        )

        annotated
      rescue PassOneError => e
        @logger.send_message(
          message: "pipeline_pass_one_failed",
          priority: Journald::LOG_ERR,
          correlation_id:,
          error: e.message
        )
        raise
      rescue PassTwoError => e
        @logger.send_message(
          message: "pipeline_pass_two_failed",
          priority: Journald::LOG_ERR,
          correlation_id:,
          error: e.message
        )
        raise
      end

      # Process only Pass 1 (syntactic + ideational).
      # Useful when you want to batch Pass 2 separately.
      #
      # @param text [String]
      # @param document_id [String, nil]
      # @return [Array<[Types::SyntacticClause, Types::IdeationalPayload]>]
      def compile_pass_one(text, document_id: nil)
        clauses = @pass_one.process(text, document_id:)
        clauses.map do |clause|
          [clause, @ideational_extractor.extract(clause)]
        end
      end

      # Process only Pass 2 (semantic annotation).
      # Takes pre-computed Pass 1 output.
      #
      # @param clause [Types::SyntacticClause]
      # @param ideational [Types::IdeationalPayload]
      # @return [Types::AnnotatedClause]
      def compile_pass_two(clause, ideational, semantic_coherence_score: nil)
        if semantic_coherence_score.nil?
          @pass_two.annotate(clause, ideational)
        else
          @pass_two.annotate(clause, ideational, semantic_coherence_score: semantic_coherence_score)
        end
      end

      # Access the cache for external operations (clear, stats).
      # @return [Storage::PipelineCache, nil]
      attr_reader :cache

      # Compile with cache: serve hits from disk, run Pass 2 only for misses.
      private def compile_with_cache(document_id, pairs, correlation_id, semantic_coherence_score = nil)
        cached, uncached = @cache.partition(document_id, pairs)

        if uncached.empty?
          @logger.send_message(
            message: "pass_two_cache_full_hit",
            priority: Journald::LOG_INFO,
            correlation_id:,
            document_id:,
            clause_count: cached.size
          )
          return cached
        end

        @logger.send_message(
          message: "pass_two_cache_partial_hit",
          priority: Journald::LOG_INFO,
          correlation_id:,
          document_id:,
          cached_count: cached.size,
          uncached_count: uncached.size
        )

        # Run Pass 2 only on uncached clauses
        fresh = if semantic_coherence_score.nil?
          @pass_two.annotate_batch(uncached)
        else
          @pass_two.annotate_batch(uncached, semantic_coherence_score: semantic_coherence_score)
        end

        # Merge: cached results first (in order), then fresh results
        # We need to rebuild the full list in original order
        result = []
        uncached_idx = 0
        pairs.each_with_index do |(clause, _ideational), _idx|
          hit = @cache.fetch(document_id, clause)
          if hit
            result << hit
          else
            result << fresh[uncached_idx]
            uncached_idx += 1
          end
        end

        result
      end
    end
  end
end
