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
    # Usage:
    #   pipeline = SFL::Compiler::Pipeline.new(db: db)
    #   results = pipeline.compile("Your text here", document_id: "doc-1")
    class Pipeline
      def initialize(db:, spacy_model: nil, embedder: nil)
        @db = db
        @pass_one = PassOneEngine.new(model: spacy_model)
        @ideational_extractor = IdeationalExtractor.new
        @pass_two = PassTwoEngine.new
        @clause_repo = ClauseRepository.new(db)
        @embedding_repo = EmbeddingRepository.new(db)
        # Embedder is optional — only required for the `embed: true` path of
        # compile(). Pass nil to defer resolution until the class is implemented.
        @embedder = embedder
        @logger = Journald::Logger.new("sfl-compiler-pipeline")
      end

      # Compile a full document through both passes.
      #
      # @param text [String] Raw text to compile
      # @param document_id [String, nil] Source document identifier
      # @param store [Boolean] Whether to persist to database
      # @param embed [Boolean] Whether to generate and store embeddings
      # @return [Array<Types::AnnotatedClause>]
      def compile(text, document_id: nil, store: true, embed: true)
        start_time = Time.now
        correlation_id = SecureRandom.uuid

        @logger.send_message(
          message: "pipeline_started",
          priority: Journald::LOG_INFO,
          correlation_id: correlation_id,
          document_id: document_id,
          text_length: text.length
        )

        # === PASS 1: Syntactic Extraction ===
        syntactic_clauses = @pass_one.process(text, document_id: document_id)

        # === PASS 1 Post-Processing: Ideational Extraction ===
        ideational_payloads = syntactic_clauses.map do |clause|
          @ideational_extractor.extract(clause)
        end

        # === PASS 2: Semantic Annotation (DSPy.rb, batched) ===
        # Sweep Pass 1's dead PyCall wrappers NOW, on this thread. If GC
        # instead triggers on a Pass 2 worker, pycall_pyptr_free blocks on
        # the Python GIL while holding the GVL — deadlocking the whole VM
        # (observed live: gc_sweep → PyGILState_Ensure → take_gil, with the
        # Timeout watchdog and HTTP reads frozen behind the GVL).
        GC.start

        annotated = @pass_two.annotate_batch(syntactic_clauses.zip(ideational_payloads))

        # === Storage ===
        if store
          annotated.each do |ac|
            @clause_repo.store(ac)
          end
        end

        # === Embedding ===
        if embed && @embedder
          annotated.each do |ac|
            embedding = @embedder.embed(ac.text)
            if embedding
              @embedding_repo.store(ac.id, embedding)
            end
          end
        end

        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "pipeline_completed",
          priority: Journald::LOG_INFO,
          correlation_id: correlation_id,
          document_id: document_id,
          clause_count: annotated.length,
          stored: store,
          embedded: embed,
          latency_ms: elapsed_ms
        )

        annotated
      rescue PassOneError => e
        @logger.send_message(
          message: "pipeline_pass_one_failed",
          priority: Journald::LOG_ERR,
          correlation_id: correlation_id,
          error: e.message
        )
        raise
      rescue PassTwoError => e
        @logger.send_message(
          message: "pipeline_pass_two_failed",
          priority: Journald::LOG_ERR,
          correlation_id: correlation_id,
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
        clauses = @pass_one.process(text, document_id: document_id)
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
      def compile_pass_two(clause, ideational)
        @pass_two.annotate(clause, ideational)
      end
    end
  end
end
