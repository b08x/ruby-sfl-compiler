# frozen_string_literal: true

require "circuit_breaker"
require "dspy"
require "timeout"
require "dry/monads"
require "journald/logger"

module SFL
  module Compiler
    # Pass Two: Semantic Annotation Engine
    #
    # Uses DSPy.rb to map syntactic structures onto SFL metafunctions.
    # Each DSPy::Signature defines a typed contract for LLM-based
    # annotation of a specific SFL dimension.
    #
    # DSPy configuration must be set externally before calling
    # `DSPy.configure { |c| c.lm = ... }`.
    class PassTwoEngine
      include Dry::Monads[:result]

      # Clauses per LLM call and concurrent in-flight calls. One call per
      # clause measured ~10 clauses/min; batching cuts the call count ~12x
      # and the thread pool overlaps the I/O-bound round-trips.
      DEFAULT_BATCH_SIZE = ENV.fetch("SFL_BATCH_SIZE", 12).to_i
      DEFAULT_CONCURRENCY = ENV.fetch("SFL_CONCURRENCY", 4).to_i

      # Watchdog for a single chunk's LLM call. HTTP-level timeouts don't
      # cover every hang (observed: response bytes sitting unread in the
      # socket while the async reactor deadlocks on a mutex), so the worker
      # thread gets a hard Timeout that the retry/fallback ladder catches.
      DEFAULT_CHUNK_TIMEOUT = ENV.fetch("SFL_CHUNK_TIMEOUT", 180).to_f

      def initialize(provider: nil, circuit_breaker: nil, batch_annotator: nil,
        chunk_timeout: DEFAULT_CHUNK_TIMEOUT
      )
        @provider = provider || SFL::Compiler.config.dspy_provider
        @circuit_breaker = circuit_breaker || default_circuit_breaker
        @batch_annotator = batch_annotator || default_batch_annotator
        @chunk_timeout = chunk_timeout
        @logger = Journald::Logger.new("sfl-compiler-pass-two")
      end

      # Annotate many clauses with batched, concurrent LLM calls.
      #
      # @param pairs [Array<[Types::SyntacticClause, Types::IdeationalPayload]>]
      # @param batch_size [Integer] clauses per LLM call
      # @param concurrency [Integer] concurrent LLM calls
      # @return [Array<Types::AnnotatedClause>] in input order; clauses the
      #   LLM missed or returned invalid values for carry fallback defaults
      def annotate_batch(pairs, batch_size: DEFAULT_BATCH_SIZE, concurrency: DEFAULT_CONCURRENCY, semantic_coherence_score: nil)
        return [] if pairs.empty?

        start_time = Time.now
        correlation_id = SecureRandom.uuid

        indexed = pairs.each_with_index.map do |(clause, ideational), index|
          { index:, clause:, ideational: }
        end
        chunks = indexed.each_slice([batch_size, 1].max).to_a

        @logger.send_message(
          message: "pass_two_batch_started",
          priority: Journald::LOG_INFO,
          correlation_id:,
          clause_count: pairs.size,
          chunk_count: chunks.size,
          concurrency:
        )

        annotated = parallel_map(chunks, concurrency) do |chunk|
          annotate_chunk(chunk, correlation_id, semantic_coherence_score)
        end.flatten

        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "pass_two_batch_completed",
          priority: Journald::LOG_INFO,
          correlation_id:,
          clause_count: annotated.size,
          defaulted_count: annotated.count { |a| a.interpersonal.annotation_source != "llm" },
          latency_ms: elapsed_ms
        )

        annotated
      end

      # Annotate a clause with SFL metafunctions.
      #
      # @param clause [Types::SyntacticClause] from Pass 1
      # @param ideational [Types::IdeationalPayload] from Pass 1 post-processing
      # @return [Types::AnnotatedClause]
      def annotate(clause, ideational, semantic_coherence_score: nil)
        start_time = Time.now
        correlation_id = SecureRandom.uuid

        @logger.send_message(
          message: "pass_two_started",
          priority: Journald::LOG_INFO,
          correlation_id:,
          clause_id: clause.id,
          text_length: clause.text.length
        )

        # Run DSPy annotation for Interpersonal features
        interpersonal, textual = annotate_interpersonal(clause, ideational, correlation_id, semantic_coherence_score)

        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "pass_two_completed",
          priority: Journald::LOG_INFO,
          correlation_id:,
          clause_id: clause.id,
          modality_weight: interpersonal.modality_weight,
          tenor: interpersonal.tenor,
          mood: interpersonal.mood,
          latency_ms: elapsed_ms
        )

        Types::AnnotatedClause.new(
          id: SecureRandom.uuid,
          text: clause.text,
          syntactic: clause,
          ideational:,
          interpersonal:,
          textual:,
          document_id: clause.document_id,
          compiled_at: Time.now
        )
      rescue => e
        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "pass_two_failed",
          priority: Journald::LOG_ERR,
          correlation_id:,
          clause_id: clause.id,
          error_class: e.class.name,
          error_message: e.message,
          latency_ms: elapsed_ms
        )

        raise PassTwoError, "Semantic annotation failed: #{e.message}"
      end



      # Returns a transparent callable that simply yields the block.
      # TODO: replace with a proper CircuitBreaker::CircuitHandler once
      #       Pass 2 is in active use and failure rates are monitored.
      # The rescue on CircuitBreaker::OpenError in annotate_interpersonal
      # handles the tripped case when a real handler is substituted in.
      private def default_circuit_breaker
        -> (&block) { block.call }
      end

      # items: [{index:, context:}] → [{index:, mood:, modality_weight:, ...}]
      private def default_batch_annotator
        -> (items) { SFLBatchAnnotator.new(items).call }
      end

      # Run one chunk through the LLM. A failed call defaults the whole
      # chunk; a missing or invalid annotation defaults only that clause.
      private def annotate_chunk(chunk, correlation_id, semantic_coherence_score = nil)
        items = chunk.map do |entry|
          {
            index: entry[:index],
            context: format_syntactic_context(entry[:clause], entry[:ideational], semantic_coherence_score),
          }
        end

        # One retry for transient provider errors; an open circuit means the
        # provider is known-bad, so don't hammer it again.
        results = begin
          @circuit_breaker.call { call_annotator_with_watchdog(items) }
        rescue CircuitBreaker::CircuitBrokenException
          raise
        rescue
          @circuit_breaker.call { call_annotator_with_watchdog(items) }
        end
        by_index = results.to_h { |r| [r[:index], r] }

        chunk.map do |entry|
          result = by_index[entry[:index]]
          interpersonal = result && interpersonal_from(entry[:clause], result, correlation_id)
          textual = result && textual_from(entry[:clause], result, correlation_id)

          if interpersonal.nil? || textual.nil?
            if result.nil?
              log_and_warn("pass_two_missing_annotation", correlation_id, entry[:clause],
                "No annotation returned for clause index #{entry[:index]} — defaults applied")
            end
            interpersonal ||= default_interpersonal(entry[:clause].id)
            textual ||= default_textual(entry[:clause].id)
          end
          annotated_clause(entry, interpersonal, textual)
        end
      rescue CircuitBreaker::CircuitBrokenException
        log_and_warn("pass_two_circuit_open", correlation_id, chunk.first[:clause],
          "Circuit breaker open — defaults applied to #{chunk.size} clauses")
        chunk.map do |entry|
          annotated_clause(entry, default_interpersonal(entry[:clause].id), default_textual(entry[:clause].id))
        end
      rescue => e
        log_and_warn("pass_two_batch_failed", correlation_id, chunk.first[:clause],
          "Batch annotation failed: #{e.message} — defaults applied to #{chunk.size} clauses")
        chunk.map do |entry|
          annotated_clause(entry, default_interpersonal(entry[:clause].id), default_textual(entry[:clause].id))
        end
      end

      # Timeout::Error is a StandardError, so a hung call flows through the
      # same retry-once-then-default path as any provider exception. A
      # timeout of 0/nil disables the watchdog.
      private def call_annotator_with_watchdog(items)
        return @batch_annotator.call(items) if @chunk_timeout.nil? || @chunk_timeout.zero?

        Timeout.timeout(@chunk_timeout, Timeout::Error,
          "LLM call exceeded #{@chunk_timeout}s chunk timeout") do
          @batch_annotator.call(items)
        end
      end

      private def interpersonal_from(clause, result, correlation_id)
        mood, status = ClassificationRegistry.normalize(:mood, result[:mood])

        if status == :unknown
          log_and_warn("pass_two_schema_gap", correlation_id, clause,
            "Invalid mood '#{result[:mood]}' normalized to '#{mood}'. " \
            "Consider adding it to ClassificationRegistry::MOOD.")
        end

        Types::InterpersonalPayload.new(
          clause_id: clause.id,
          mood:,
          modality_weight: clamp01(result[:modality_weight] || 0.5),
          tenor: clamp01(result[:tenor] || 0.5),
          speaker_attitude: result[:speaker_attitude],
          reasoning: result[:reasoning],
          annotation_source: "llm"
        )
      rescue Dry::Struct::Error => e
        log_and_warn("pass_two_invalid_interpersonal", correlation_id, clause,
          "Invalid interpersonal values: #{e.message} — defaults applied")
        nil
      end

      private def textual_from(clause, result, correlation_id)
        theme_type, status = ClassificationRegistry.normalize(:theme_type, result[:theme_type])

        if status == :unknown
          log_and_warn("pass_two_schema_gap", correlation_id, clause,
            "Invalid theme_type '#{result[:theme_type]}' normalized to '#{theme_type}'. " \
            "Consider adding it to ClassificationRegistry::THEME_TYPE.")
        end

        Types::TextualPayload.new(
          clause_id: clause.id,
          topical_theme: result[:topical_theme] || clause.text.split.first,
          textual_theme: result[:textual_theme],
          interpersonal_theme: result[:interpersonal_theme],
          rheme: result[:rheme],
          theme_type:
        )
      rescue Dry::Struct::Error => e
        log_and_warn("pass_two_invalid_textual", correlation_id, clause,
          "Invalid textual values: #{e.message} — defaults applied")
        nil
      end

      private def annotated_clause(entry, interpersonal, textual)
        Types::AnnotatedClause.new(
          id: SecureRandom.uuid,
          text: entry[:clause].text,
          syntactic: entry[:clause],
          ideational: entry[:ideational],
          interpersonal:,
          textual:,
          document_id: entry[:clause].document_id,
          compiled_at: Time.now
        )
      end

      # Map chunks to results on a bounded thread pool, preserving order.
      # Worker exceptions can't corrupt results: annotate_chunk rescues
      # StandardError internally, so each slot is always filled.
      private def parallel_map(chunks, concurrency, &block)
        workers = [concurrency, chunks.size].min
        return chunks.map(&block) if workers <= 1

        results = Array.new(chunks.size)
        queue = Queue.new
        chunks.each_with_index { |chunk, i| queue << [chunk, i] }
        queue.close

        Array.new(workers) do
          Thread.new do
            while (job = queue.pop)
              chunk, i = job
              results[i] = block.call(chunk)
            end
          end
        end.each(&:join)

        results
      end

      private def annotate_interpersonal(clause, ideational, correlation_id, semantic_coherence_score = nil)
        # Build the syntactic context for the LLM
        syntactic_context = format_syntactic_context(clause, ideational, semantic_coherence_score)

        # Call DSPy through circuit breaker for resilience
        result = @circuit_breaker.call do
          sfl_annotator = SFLAnnotator.new(syntactic_context)
          sfl_annotator.call
        end

        interpersonal = interpersonal_from(clause, result, correlation_id)
        interpersonal ||= default_interpersonal(clause.id)

        textual = textual_from(clause, result, correlation_id)
        textual ||= default_textual(clause.id)

        [interpersonal, textual]
      rescue CircuitBreaker::CircuitBrokenException
        log_and_warn("pass_two_circuit_open", correlation_id, clause,
          "Circuit breaker open — defaults applied")
        [default_interpersonal(clause.id), default_textual(clause.id)]
      rescue => e
        log_and_warn("pass_two_llm_failed", correlation_id, clause,
          "DSPy annotation failed: #{e.message}")
        [default_interpersonal(clause.id), default_textual(clause.id)]
      end

      private def format_syntactic_context(clause, ideational, semantic_coherence_score = nil)
        context = <<~CONTEXT
          Text: #{clause.text}

          Root verb: #{root_info(clause)}
          Process type: #{ideational.process_type}
          Participants: #{ideational.participants.join(', ')}
          POS tags: #{pos_sequence(clause)}
          Dependencies: #{dep_sequence(clause)}
        CONTEXT
        context += "Semantic coherence score: #{semantic_coherence_score}\n" if semantic_coherence_score
        context
      end

      private def root_info(clause)
        root = clause.tokens[clause.root_index]
        return "unknown" if root.nil?

        "#{root.text} (lemma: #{root.lemma}, pos: #{root.pos}, tag: #{root.tag})"
      end

      private def pos_sequence(clause)
        clause.tokens.map { |t| "#{t.text}/#{t.pos}" }.join(" ")
      end

      private def dep_sequence(clause)
        clause.tokens.map { |t| "#{t.text}<#{t.dep}" }.join(" ")
      end

      private def default_interpersonal(clause_id)
        Types::InterpersonalPayload.new(
          clause_id:,
          mood: "declarative",
          modality_weight: 0.5,
          tenor: 0.5,
          speaker_attitude: nil,
          reasoning: "Circuit breaker open — defaults applied",
          annotation_source: "fallback"
        )
      end

      private def default_textual(clause_id)
        Types::TextualPayload.new(
          clause_id:,
          topical_theme: "unknown",
          textual_theme: nil,
          interpersonal_theme: nil,
          rheme: nil,
          theme_type: "unmarked"
        )
      end

      # Clamp a numeric value to [0.0, 1.0]. Handles LLMs that output
      # on a 1-5 or 0-10 scale by treating values >1 as needing division.
      private def clamp01(value)
        return 0.0 if value.nil?
        return value.clamp(0.0, 1.0) if value <= 1.0

        # Likely a 1-5 or similar scale; normalize down
        normalized = value / 5.0
        normalized.clamp(0.0, 1.0)
      end

      private def log_and_warn(message, correlation_id, clause, human_message)
        @logger.send_message(
          message:,
          priority: Journald::LOG_WARNING,
          correlation_id:,
          clause_id: clause.id
        )
        warn "[WARN] Pass 2 (#{clause.id}): #{human_message}"
      end
    end

    # DSPy.rb signature for SFL interpersonal and textual annotation.
    # NOTE: Processes belong to the Ideational metafunction (handled in Pass 1).
    # This signature handles Interpersonal (mood, modality, tenor) and
    # Textual (Theme/Rheme organization) metafunctions only.
    class SFLSignature < DSPy::Signature
      description "Analyze the interpersonal and textual metafunctions of a clause using " \
        "Systemic Functional Linguistics (SFL). " \
        "Interpersonal: mood type, modality weight (certainty), tenor (formality), speaker attitude. " \
        "Textual: Theme/Rheme structure — Theme is the starting point of the message."

      input do
        const :text, String, description: "The raw clause text"
        const :root_verb, String, description: "The root verb with POS and lemma (from Pass 1 Ideational analysis)"
        const :process_type, String,
          description: "Ideational process type (from Pass 1 — for context only, not analyzed here)"
        const :participants, String, description: "Semantic roles of participants (from Pass 1 — for context only)"
        const :pos_tags, String, description: "POS tag sequence"
        const :dependencies, String, description: "Dependency relation sequence"
        const :semantic_coherence_score, Float,
          description: "Semantic coherence score of the parent turn relative to the conversation baseline (0.0 to 1.0, lower means more anomalous/off-topic)"
      end

      output do
        const :mood, String,
          description: "Clause mood: #{ClassificationRegistry.signature_description(:mood)}"
        const :modality_weight, Float, description: "Modality strength 0.0-1.0 (0=weak/hedged, 1=strong/certain)"
        const :tenor, Float, description: "Formality level 0.0-1.0 (0=informal, 1=formal)"
        const :speaker_attitude, String,
          description: "Speaker attitude: neutral, positive, negative, skeptical, assertive"
        const :topical_theme, String,
          description: "Topical Theme: main starting point (Subject, fronted element, or Predicator)"
        const :textual_theme, String,
          description: "Textual Theme: conjunctions/connectives at start (e.g., however, therefore, and)"
        const :interpersonal_theme, String,
          description: "Interpersonal Theme: modal adjuncts/discourse markers at start (e.g., surely, perhaps, well)"
        const :rheme, String, description: "Rheme: everything after the Theme"
        const :theme_type, String,
          description: "Theme type: #{ClassificationRegistry.signature_description(:theme_type)}"
        const :reasoning, String, description: "Step-by-step reasoning for the classification"
      end
    end

    # DSPy annotator module using ChainOfThought for reasoning.
    class SFLAnnotator
      def initialize(syntactic_context)
        @context = syntactic_context
      end

      def call
        # Parse the formatted context back into DSPy signature inputs
        inputs = parse_context(@context)

        predictor = DSPy::ChainOfThought.new(SFLSignature)
        result = predictor.call(**inputs)

        {
          mood: result.mood,
          modality_weight: result.modality_weight,
          tenor: result.tenor,
          speaker_attitude: result.speaker_attitude,
          topical_theme: result.topical_theme,
          textual_theme: result.textual_theme,
          interpersonal_theme: result.interpersonal_theme,
          rheme: result.rheme,
          theme_type: result.theme_type,
          reasoning: result.reasoning,
        }
      end

      private def parse_context(context)
        lines = context.strip.split("\n")
        lines = lines.map { |l| l.split(":", 2) }

        text = extract_field(lines, "Text") || ""
        root_verb = extract_field(lines, "Root verb") || "unknown"
        process_type = extract_field(lines, "Process type") || "material"
        participants = extract_field(lines, "Participants") || ""
        pos_tags = extract_field(lines, "POS tags") || ""
        dependencies = extract_field(lines, "Dependencies") || ""
        semantic_coherence_score_str = extract_field(lines, "Semantic coherence score")
        semantic_coherence_score = semantic_coherence_score_str ? semantic_coherence_score_str.to_f : 1.0

        {
          text:,
          root_verb:,
          process_type:,
          participants:,
          pos_tags:,
          dependencies:,
          semantic_coherence_score:,
        }
      end

      private def extract_field(lines, key)
        line = lines.find { |l| l[0]&.strip == key }
        line&.[](1)&.strip
      end
    end

    # One annotation row in a batched Pass 2 response.
    class ClauseAnnotation < T::Struct
      const :index, Integer
      const :mood, String
      const :modality_weight, Float
      const :tenor, Float
      const :speaker_attitude, T.nilable(String)
      const :topical_theme, String
      const :textual_theme, T.nilable(String)
      const :interpersonal_theme, T.nilable(String)
      const :rheme, T.nilable(String)
      const :theme_type, String
      const :reasoning, T.nilable(String)
    end

    # Batched variant of SFLSignature: annotates many clauses per LLM call.
    class SFLBatchSignature < DSPy::Signature
      description "Analyze the interpersonal and textual metafunctions of EACH numbered clause " \
        "using Systemic Functional Linguistics (SFL). " \
        "Interpersonal: mood, modality, tenor, speaker attitude. " \
        "Textual: Theme/Rheme structure. " \
        "Processes (material, mental, relational, etc.) are Ideational — handled in Pass 1. " \
        "Return exactly one annotation per clause, carrying over the index."

      input do
        const :clauses, String,
          description: "Numbered clauses, each with text, root verb, process type " \
            "(from Pass 1 Ideational — for context only), " \
            "participants, POS tags, and dependency relations"
      end

      output do
        const :annotations, T::Array[ClauseAnnotation],
          description: "Exactly one annotation per input clause, with matching index"
      end
    end

    # DSPy annotator for batched clause annotation.
    class SFLBatchAnnotator
      # @param items [Array<Hash>] [{index: Integer, context: String}]
      def initialize(items)
        @items = items
      end

      # @return [Array<Hash>] one hash per annotation the LLM returned
      def call
        input_text = @items.map do |item|
          "### Clause #{item[:index]}\n#{item[:context]}"
        end.join("\n")

        predictor = DSPy::ChainOfThought.new(SFLBatchSignature)
        result = predictor.call(clauses: input_text)

        result.annotations.map do |a|
          {
            index: a.index,
            mood: a.mood,
            modality_weight: a.modality_weight,
            tenor: a.tenor,
            speaker_attitude: a.speaker_attitude,
            topical_theme: a.topical_theme,
            textual_theme: a.textual_theme,
            interpersonal_theme: a.interpersonal_theme,
            rheme: a.rheme,
            theme_type: a.theme_type,
            reasoning: a.reasoning,
          }
        end
      end
    end
  end
end
