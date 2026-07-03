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
      # Lowered from 180s: observed p50 is ~35s, p95 ~90s. 120s gives
      # legitimate slow calls room to complete while cutting worst-case
      # per-attempt wait from 3min to 2min (total: 3×120s = 6min max vs
      # 3×180s = 9min). Override with SFL_CHUNK_TIMEOUT=N in .env.
      DEFAULT_CHUNK_TIMEOUT = ENV.fetch("SFL_CHUNK_TIMEOUT", 120).to_f

      # Total attempts per chunk before falling back to defaults. Raised
      # from 2 (one retry) after a live reproduction against the real
      # provider found ~15-20% of batch calls fail with a truncated/
      # incomplete JSON response (DSPy::LM::AdapterError) — independent
      # of batch_size, so this isn't a token-budget problem to fix by
      # shrinking chunks, it's provider-side flakiness to absorb with
      # more attempts. With ~15% independent failure probability, 2
      # attempts still fails ~2-4% of chunks; 3 attempts cuts that to
      # ~0.3%, which is what actually stops a long run from flooding
      # stderr with repeated chunk-failure warnings.
      DEFAULT_BATCH_ATTEMPTS = ENV.fetch("SFL_BATCH_ATTEMPTS", 3).to_i

      def initialize(provider: nil, circuit_breaker: nil, batch_annotator: nil,
        chunk_timeout: DEFAULT_CHUNK_TIMEOUT, batch_attempts: DEFAULT_BATCH_ATTEMPTS,
        provider_chain: nil, on_gas_exhausted: nil
      )
        @provider = provider || SFL::Compiler.config.dspy_provider
        @logger = Journald::Logger.new("sfl-compiler-pass-two")
        @chunk_timeout = chunk_timeout
        @batch_attempts = batch_attempts
        @circuit_breaker = circuit_breaker || default_circuit_breaker
        @batch_annotator = batch_annotator  # nil = auto-build per entry in chain
        @provider_chain  = provider_chain || ProviderFallback.build_chain(@provider)
        @on_gas_exhausted = on_gas_exhausted
      end

      # Annotate many clauses with batched, concurrent LLM calls.
      #
      # @param pairs [Array<[Types::SyntacticClause, Types::IdeationalPayload]>]
      # @param batch_size [Integer] clauses per LLM call
      # @param concurrency [Integer] concurrent LLM calls
      # @return [Array<Types::AnnotatedClause>] in input order; clauses the
      #   LLM missed or returned invalid values for carry fallback defaults
      def annotate_batch(pairs, batch_size: DEFAULT_BATCH_SIZE, concurrency: DEFAULT_CONCURRENCY,
                         semantic_coherence_score: nil, on_chunk_done: nil)
        return [] if pairs.empty?

        start_time = Time.now
        correlation_id = SecureRandom.uuid

        indexed = pairs.each_with_index.map do |(clause, ideational), index|
          { index:, clause:, ideational: }
        end
        chunks = indexed.each_slice([batch_size, 1].max).to_a

        @logger.send_message(
          message: "pass_two_batch_started provider=#{@provider} clauses=#{pairs.size} chunks=#{chunks.size} batch_size=#{batch_size} timeout=#{@chunk_timeout}s attempts=#{@batch_attempts}",
          priority: Journald::LOG_INFO,
          correlation_id:,
          clause_count: pairs.size,
          chunk_count: chunks.size,
          concurrency:,
          provider: @provider,
          batch_size:,
          chunk_timeout: @chunk_timeout,
          batch_attempts: @batch_attempts
        )

        total = chunks.size
        done_count = 0
        done_mutex = on_chunk_done ? Mutex.new : nil

        annotated = parallel_map(chunks, concurrency) do |chunk|
          result = annotate_chunk(chunk, correlation_id, semantic_coherence_score)
          if on_chunk_done
            n = done_mutex.synchronize { done_count += 1 }
            on_chunk_done.call(n, total)
          end
          result
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
          text_length: clause.text.length,
          provider: @provider
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



      # Returns a CircuitBreaker::CircuitHandler configured from ENV.
      # The handler exposes a #call(&block) interface so callers can wrap
      # LLM invocations with the same @circuit_breaker.call { ... } pattern
      # used elsewhere in this class.
      #
      # Circuit state is tracked per-instance (each PassTwoEngine gets its
      # own breaker), so concurrent or sequential batches share the same
      # failure count and trip threshold.
      private def default_circuit_breaker
        handler = CircuitBreaker::CircuitHandler.new(@logger)
        handler.failure_threshold = ENV.fetch("SFL_CIRCUIT_FAILURE_THRESHOLD", 5).to_i
        handler.failure_timeout = ENV.fetch("SFL_CIRCUIT_RETRY_TIMEOUT", 30).to_i
        handler.invocation_timeout = @chunk_timeout

        # Give the handler a #call interface that wraps a block with the
        # circuit state.  CircuitHandler#handle expects a bound method, so
        # we define a unary proc method on the handler instance that runs
        # the block and delegates through the standard on_success/on_failure
        # lifecycle.
        state = handler.new_circuit_state
        handler.define_singleton_method(:call) do |&block|
          if handler.is_tripped(state)
            handler.on_circuit_open(state)
          end

          begin
            out = Timeout.timeout(handler.invocation_timeout, Timeout::Error) do
              res = block.call
              handler.on_success(state)
              res
            end
            out
          rescue Exception => e
            handler.on_failure(state) unless handler.excluded_exceptions.include?(e.class)
            raise
          end
        end

        handler
      end

      # Build an annotator lambda for a specific provider LM entry.
      private def annotator_for(entry)
        if @batch_annotator
          @batch_annotator  # test-injected override
        else
          -> (items) { SFLBatchAnnotator.new(items, lm: entry.lm).call }
        end
      end

      # Run one chunk through the provider chain. Tries each provider in
      # order (primary first, then fallbacks); on exhaustion, defaults.
      private def annotate_chunk(chunk, correlation_id, semantic_coherence_score = nil)
        if @circuit_breaker.respond_to?(:charge_batch)
          @circuit_breaker.charge_batch(chunk)
          if @circuit_breaker.respond_to?(:exhausted?) && @circuit_breaker.exhausted?
            trigger_rolling_synthesis(chunk, correlation_id)
            @circuit_breaker.reset!
          end
        end

        items = chunk.map do |entry|
          {
            index: entry[:index],
            context: format_syntactic_context(entry[:clause], entry[:ideational], semantic_coherence_score),
          }
        end

        results = try_providers(items, correlation_id, chunk)
        return default_chunk(chunk) if results.nil?

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
      end

      # Try each provider in the chain until one succeeds. Returns results
      # array on success, nil if every provider (and the circuit breaker)
      # is exhausted. Semantic error messages replace raw exception strings.
      #
      # When @batch_annotator is set (test-injected override), bypass the
      # provider chain entirely — the injected lambda IS the annotator.
      private def try_providers(items, correlation_id, chunk)
        if @batch_annotator
          begin
            return @circuit_breaker.call { call_with_retries(items, @batch_annotator) }
          rescue CircuitBreaker::CircuitBrokenException
            log_and_warn("pass_two_circuit_open", correlation_id, chunk.first[:clause],
              "Circuit breaker open — defaults applied to #{chunk.size} clauses",
              error_class: "CircuitBreaker::CircuitBrokenException")
            return nil
          rescue => e
            log_and_warn("pass_two_batch_failed", correlation_id, chunk.first[:clause],
              "#{ProviderFallback.classify_error(e, provider: @provider, timeout: @chunk_timeout)} — all providers exhausted, defaults applied to #{chunk.size} clauses",
              error_class: e.class.name,
              error_message: e.message)
            return nil
          end
        end

        last_error = nil
        @provider_chain.each_with_index do |entry, idx|
          begin
            annotator = annotator_for(entry)
            return @circuit_breaker.call { call_with_retries(items, annotator) }
          rescue CircuitBreaker::CircuitBrokenException
            log_and_warn("pass_two_circuit_open", correlation_id, chunk.first[:clause],
              "Circuit breaker open — skipping remaining providers",
              error_class: "CircuitBreaker::CircuitBrokenException",
              provider: entry.provider)
            return nil
          rescue => e
            last_error = e
            semantic = ProviderFallback.classify_error(e, provider: entry.provider, timeout: @chunk_timeout)
            next_provider = @provider_chain[idx + 1]&.provider

            if next_provider
              log_and_warn("pass_two_provider_failed", correlation_id, chunk.first[:clause],
                "#{semantic} — trying #{next_provider}",
                error_class: e.class.name,
                provider: entry.provider,
                next_provider:)
            else
              log_and_warn("pass_two_batch_failed", correlation_id, chunk.first[:clause],
                "#{semantic} — all providers exhausted, defaults applied to #{chunk.size} clauses",
                error_class: e.class.name,
                error_message: e.message,
                provider: entry.provider)
            end
          end
        end
        nil
      end

      # Called when CognitiveGas budget is exhausted mid-batch. Fires the
      # on_gas_exhausted callback (if provided) with the IDs of the clauses
      # in the current chunk, then the caller resets the budget so processing
      # can continue. The callback is responsible for enqueuing
      # IntermediateGenieJob; PassTwoEngine stays job-agnostic.
      private def trigger_rolling_synthesis(chunk, correlation_id)
        clause_ids = chunk.map { |e| e[:clause].id }
        @logger.send_message(
          message: "cognitive_gas_exhausted",
          priority: Journald::LOG_WARNING,
          correlation_id:,
          clause_count: clause_ids.size,
          spent: @circuit_breaker.spent,
          budget: @circuit_breaker.budget
        )
        warn "[WARN] CognitiveGas budget exhausted " \
             "(#{@circuit_breaker.spent}/#{@circuit_breaker.budget}) — " \
             "triggering rolling synthesis, resetting budget"
        @on_gas_exhausted&.call(clause_ids)
      end

      private def default_chunk(chunk)
        chunk.map do |entry|
          annotated_clause(entry, default_interpersonal(entry[:clause].id), default_textual(entry[:clause].id))
        end
      end

      # Timeout::Error is a StandardError, so a hung call flows through the
      # same retry-once-then-default path as any provider exception. A
      # timeout of 0/nil disables the watchdog.
      private def call_with_watchdog(items, annotator)
        return annotator.call(items) if @chunk_timeout.nil? || @chunk_timeout.zero?

        Timeout.timeout(@chunk_timeout, Timeout::Error,
          "LLM call exceeded #{@chunk_timeout}s chunk timeout") do
          annotator.call(items)
        end
      end

      # Up to @batch_attempts independent tries with the given annotator.
      # The last error propagates once every attempt is exhausted so
      # try_providers can log it and advance to the next provider.
      private def call_with_retries(items, annotator)
        last_error = nil
        @batch_attempts.times do
          return call_with_watchdog(items, annotator)
        rescue => e
          last_error = e
        end
        raise last_error
      end

      private def interpersonal_from(clause, result, correlation_id)
        mood, status = ClassificationRegistry.normalize(:mood, result[:mood])
        log_classification_gap(:mood, status, result[:mood], mood, correlation_id, clause)

        modality_weight = clamp01(result[:modality_weight] || 0.5)
        tenor = clamp01(result[:tenor] || 0.5)
        conclusion = { mood:, modality_weight:, tenor:, speaker_attitude: result[:speaker_attitude] }

        Types::InterpersonalPayload.new(
          clause_id: clause.id,
          mood:,
          modality_weight:,
          tenor:,
          speaker_attitude: result[:speaker_attitude],
          reasoning: result[:reasoning],
          annotation_source: "llm",
          reasoning_trace: safe_reasoning_trace_from(result, conclusion, clause, correlation_id)
        )
      rescue Dry::Struct::Error => e
        log_and_warn("pass_two_invalid_interpersonal", correlation_id, clause,
          "Invalid interpersonal values: #{e.message} — defaults applied")
        nil
      end

      # A malformed reasoning trace (e.g. an unparseable premise) must
      # never default the clause's actual mood/tenor/modality — those came
      # back correctly from the LLM; only the provenance layer is at risk.
      # Caught live: an earlier Types::Premise#type enum rejected a real
      # model's premise category, and because this call originally sat
      # inside #interpersonal_from's own rescue, one bad premise defaulted
      # the entire clause, not just its reasoning_trace.
      private def safe_reasoning_trace_from(result, conclusion, clause, correlation_id)
        reasoning_trace_from(result, conclusion)
      rescue Dry::Struct::Error => e
        log_and_warn("pass_two_invalid_reasoning_trace", correlation_id, clause,
          "Invalid reasoning trace: #{e.message} — reasoning_trace left nil, interpersonal values unaffected")
        nil
      end

      # Bridges a DSPy result hash's premises/inference_rule into the
      # internal Types::ReasoningTrace. derivation_hash is computed here
      # from the actual returned values, never read from an LLM output
      # field — an LLM-emitted hash would verify nothing, since the model
      # could emit any string it wants.
      private def reasoning_trace_from(result, conclusion)
        premises = (result[:premises] || []).map do |p|
          Types::Premise.new(type: p.type, source: p.source, value: p.value, weight: p.weight)
        end
        inference_rule = result[:inference_rule] || "unknown"

        Types::ReasoningTrace.new(
          premises:,
          inference_rule:,
          conclusion:,
          confidence: clamp01(result[:confidence] || 0.5),
          derivation_hash: DerivationHash.compute(premises:, inference_rule:, conclusion:),
          generated_at: ::Time.now
        )
      end

      private def textual_from(clause, result, correlation_id)
        theme_type, status = ClassificationRegistry.normalize(:theme_type, result[:theme_type])
        log_classification_gap(:theme_type, status, result[:theme_type], theme_type, correlation_id, clause)

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
        syntactic_context = format_syntactic_context(clause, ideational, semantic_coherence_score)

        result = nil
        last_error = nil
        @provider_chain.each do |entry|
          begin
            result = @circuit_breaker.call do
              SFLAnnotator.new(syntactic_context, lm: entry.lm).call
            end
            break
          rescue CircuitBreaker::CircuitBrokenException
            cb_msg = last_error \
              ? "DSPy annotation failed: #{last_error.message} (circuit breaker open — defaults applied)" \
              : "Circuit breaker open — defaults applied"
            log_and_warn("pass_two_circuit_open", correlation_id, clause, cb_msg,
              error_class: "CircuitBreaker::CircuitBrokenException")
            return [default_interpersonal(clause.id), default_textual(clause.id)]
          rescue => e
            last_error = e
            semantic = ProviderFallback.classify_error(e, provider: entry.provider, timeout: @chunk_timeout)
            log_and_warn("pass_two_llm_failed", correlation_id, clause,
              semantic,
              error_class: e.class.name,
              provider: entry.provider)
          end
        end

        if result.nil?
          log_and_warn("pass_two_llm_failed", correlation_id, clause,
            "DSPy annotation failed: #{last_error&.message || 'unknown'}",
            error_class: last_error&.class&.name)
          return [default_interpersonal(clause.id), default_textual(clause.id)]
        end

        interpersonal = interpersonal_from(clause, result, correlation_id)
        interpersonal ||= default_interpersonal(clause.id)

        textual = textual_from(clause, result, correlation_id)
        textual ||= default_textual(clause.id)

        [interpersonal, textual]
      rescue => e
        log_and_warn("pass_two_llm_failed", correlation_id, clause,
          "DSPy annotation failed: #{e.message}",
          error_class: e.class.name,
          error_message: e.message)
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

      # Shared WARN wiring for both ClassificationRegistry dimensions
      # (mood in interpersonal_from, theme_type in textual_from).
      # :unknown means the value fell through to the default — a real
      # schema gap. :fuzzy means Jaro-Winkler resolved a near-miss to a
      # real category — the value is good, but it still gets surfaced
      # (never silent) so the alias table can gain a permanent entry
      # instead of paying the fuzzy scan on every future run.
      private def log_classification_gap(dimension, status, raw, resolved, correlation_id, clause)
        registry_const = "ClassificationRegistry::#{dimension.to_s.upcase}"
        case status
        when :unknown
          log_and_warn("pass_two_schema_gap", correlation_id, clause,
            "Invalid #{dimension} '#{raw}' normalized to '#{resolved}'. " \
            "Consider adding it to #{registry_const}.",
            unknown_value: raw.to_s)
        when :fuzzy
          log_and_warn("pass_two_fuzzy_match", correlation_id, clause,
            "#{dimension.to_s.capitalize} '#{raw}' fuzzy-matched to '#{resolved}'. " \
            "Consider adding an explicit alias to #{registry_const}.",
            unknown_value: raw.to_s)
        end
      end

      private def log_and_warn(message, correlation_id, clause, human_message, **extra)
        journal_message = extra[:error_class] ? "#{message} error=#{extra[:error_class]}" : message
        journal_message += " unknown_value=#{extra[:unknown_value]}" if extra[:unknown_value]
        @logger.send_message(
          message: journal_message,
          priority: Journald::LOG_WARNING,
          correlation_id:,
          clause_id: clause.id,
          **extra
        )
        warn "[WARN] Pass 2 (#{clause.id}): #{human_message}"
      end
    end

    # One piece of evidence (token/POS/dep/etc.) the LLM cites as support
    # for an annotation decision. Sorbet T::Struct, not Dry::Struct — this
    # is the DSPy output-boundary type; `Types::Premise` (Dry::Struct) is
    # the internal representation it gets bridged into downstream.
    class PremiseOutput < T::Struct
      const :type, String
      const :source, String
      const :value, String
      const :weight, T.nilable(Float)
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
        const :premises, T::Array[PremiseOutput],
          description: "Specific tokens/POS/deps/etc. that support this annotation"
        const :inference_rule, String,
          description: "Named SFL rule mapping premises to the conclusion, e.g. 'tenor_high_formal_register'"
      end
    end

    # DSPy annotator module using ChainOfThought for reasoning.
    class SFLAnnotator
      def initialize(syntactic_context, lm: nil)
        @context = syntactic_context
        @lm = lm
      end

      def call
        # Parse the formatted context back into DSPy signature inputs
        inputs = parse_context(@context)

        predictor = DSPy::ChainOfThought.new(SFLSignature)
        predictor.configure { |c| c.lm = @lm } if @lm
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
          premises: result.premises,
          inference_rule: result.inference_rule,
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
      const :premises, T::Array[PremiseOutput], default: []
      const :inference_rule, T.nilable(String)
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
      # @param lm [DSPy::LM, nil] per-provider LM instance; falls back to DSPy.config.lm
      def initialize(items, lm: nil)
        @items = items
        @lm = lm
      end

      # @return [Array<Hash>] one hash per annotation the LLM returned
      def call
        input_text = @items.map do |item|
          "### Clause #{item[:index]}\n#{item[:context]}"
        end.join("\n")

        predictor = DSPy::ChainOfThought.new(SFLBatchSignature)
        predictor.configure { |c| c.lm = @lm } if @lm
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
            premises: a.premises,
            inference_rule: a.inference_rule,
          }
        end
      end
    end
  end
end
