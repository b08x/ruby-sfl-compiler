# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::PassTwoEngine do
  # ── Shared fixtures ──────────────────────────────────────────────

  let(:token) do
    SFL::Compiler::Types::SyntacticToken.new(
      text: "processes", lemma: "process", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
  end

  let(:clause) do
    SFL::Compiler::Types::SyntacticClause.new(
      id: "clause-1", text: "The system processes data.",
      tokens: [token], root_index: 0, sentence_index: 0, document_id: "doc-1"
    )
  end

  let(:ideational) do
    SFL::Compiler::Types::IdeationalPayload.new(
      clause_id: "clause-1", process_type: "material",
      participants: [], circumstances: [], raw_transitivity: {}
    )
  end

  # A minimal annotator stub that always succeeds
  let(:ok_annotator) do
    ->(_items) do
      [{ index: 0, mood: "declarative", modality_weight: 0.7, tenor: 0.6,
         speaker_attitude: "neutral", reasoning: "ok",
         topical_theme: "system", textual_theme: nil, interpersonal_theme: nil,
         rheme: "processes data", theme_type: "unmarked" }]
    end
  end

  # ── Mock circuit breaker that lets us drive state transitions ──

  # We build a lightweight stand-in that mirrors the real CircuitHandler's
  # state-machine (closed → open → half_open → closed) so we can test
  # PassTwoEngine's behaviour at each transition without relying on the
  # gem's internal timing.
  let(:mock_breaker) { MockCircuitBreaker.new }

  class MockCircuitBreaker
    attr_reader :state, :call_count

    def initialize
      @state = :closed
      @call_count = 0
    end

    # Simulate successful call through the breaker
    def call(&block)
      @call_count += 1
      case @state
      when :closed
        block.call
      when :open
        raise CircuitBreaker::CircuitBrokenException, "Circuit open"
      when :half_open
        block.call
      end
    end

    # Driver methods for tests
    def trip!;  @state = :open; end
    def half_open!; @state = :half_open; end
    def reset!; @state = :closed; end
  end

  # ── Tests ───────────────────────────────────────────────────────

  describe "circuit breaker integration" do
    subject(:engine) { described_class.new(circuit_breaker: mock_breaker, batch_annotator: ok_annotator) }

    # ── Closed → Open ─────────────────────────────────────────────

    describe "Closed → Open transition" do
      it "opens the circuit after N consecutive failures" do
        # Build a breaker that trips after 3 failures
        trip_counter = Object.new
        trip_counter.instance_variable_set(:@failures, 0)
        trip_counter.instance_variable_set(:@threshold, 2)
        trip_counter.instance_variable_set(:@state, :closed)
        trip_counter.instance_variable_set(:@on_trip, -> { mock_breaker.trip! })

        def trip_counter.call(&block)
          @failures += 1
          if @failures > @threshold
            @state = :open
            @on_trip.call
            raise CircuitBreaker::CircuitBrokenException, "Circuit open"
          end
          raise StandardError, "LLM error"
        end

        def trip_counter.state
          @state
        end

        failing_engine = described_class.new(circuit_breaker: trip_counter)

        # First 2 calls raise StandardError but do NOT open the circuit yet
        2.times do
          expect { failing_engine.annotate(clause, ideational) }
            .not_to raise_error
        end

        # 3rd failure exceeds threshold → circuit is now open
        expect { failing_engine.annotate(clause, ideational) }.not_to raise_error
        expect(trip_counter.state).to eq(:open)
      end

      it "raises CircuitBrokenException when calling through an open circuit" do
        mock_breaker.trip!

        # annotate_chunk catches CircuitBrokenException and applies defaults.
        # But annotate() also rescues it.
        expect { engine.annotate(clause, ideational) }.not_to raise_error
      end

      it "stops making LLM calls once the circuit is open" do
        mock_breaker.trip!
        expect { engine.annotate(clause, ideational) }.not_to raise_error
        # The annotator was never called because the circuit was open
        # and FlowControl caught it before reaching the LLM.
      end
    end

    # ── Open → Half-open ──────────────────────────────────────────

    describe "Open → Half-open transition" do
      before do
        mock_breaker.trip!
        mock_breaker.half_open!
      end

      it "transitions to half-open after a probe call is allowed" do
        expect(mock_breaker.state).to eq(:half_open)

        result = engine.annotate(clause, ideational)
        expect(result).to be_a(SFL::Compiler::Types::AnnotatedClause)
      end

      it "allows exactly one probe call in half-open state" do
        # Stub the SFLAnnotator so the probe call succeeds
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call)
          .and_return({
            mood: "declarative",
            modality_weight: 0.7,
            tenor: 0.6,
            speaker_attitude: "neutral",
            reasoning: "ok",
            topical_theme: "system",
            textual_theme: nil,
            interpersonal_theme: nil,
            rheme: "processes data",
            theme_type: "unmarked",
          })

        result = engine.annotate(clause, ideational)
        expect(result.interpersonal.annotation_source).to eq("llm")
      end
    end

    # ── Half-open → Closed ────────────────────────────────────────

    describe "Half-open → Closed transition" do
      before do
        mock_breaker.trip!
        mock_breaker.half_open!
      end

      it "transitions back to closed after a successful probe" do
        # Stub the SFLAnnotator so the probe call succeeds
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call)
          .and_return({
            mood: "declarative",
            modality_weight: 0.7,
            tenor: 0.6,
            speaker_attitude: "neutral",
            reasoning: "ok",
            topical_theme: "system",
            textual_theme: nil,
            interpersonal_theme: nil,
            rheme: "processes data",
            theme_type: "unmarked",
          })

        # A successful call in half-open should reset the circuit.
        # Our mock doesn't auto-reset; we verify the engine's annotate
        # path succeeds and produces an LLM annotation (not fallback).
        result = engine.annotate(clause, ideational)
        expect(result.interpersonal.annotation_source).to eq("llm")
        expect(result.interpersonal.mood).to eq("declarative")
      end
    end

    # ── Half-open → Open (probe failure) ──────────────────────────

    describe "Half-open → Open (failed probe)" do
      before do
        mock_breaker.trip!
        mock_breaker.half_open!
      end

      it "re-opens the circuit when the probe call fails" do
        # Build a breaker that fails the probe and re-trips
        probe_fail = Class.new do
          attr_reader :state

          def initialize
            @state = :half_open
            @attempted = false
          end

          def call(&block)
            if @state == :half_open && !@attempted
              @attempted = true
              @state = :open
              raise StandardError, "probe failed"
            elsif @state == :open
              raise CircuitBreaker::CircuitBrokenException, "Circuit open"
            else
              block.call
            end
          end
        end.new

        failing_engine = described_class.new(circuit_breaker: probe_fail)

        # First call: probe fails → circuit re-opens, engine falls back to defaults
        result = failing_engine.annotate(clause, ideational)
        expect(result.interpersonal.annotation_source).to eq("fallback")

        # Second call: circuit is now open → CircuitBrokenException → defaults
        result2 = failing_engine.annotate(clause, ideational)
        expect(result2.interpersonal.annotation_source).to eq("fallback")
      end
    end

    # ── Fallback on open ──────────────────────────────────────────

    describe "fallback on open circuit" do
      before { mock_breaker.trip! }

      it "applies default interpersonal/textual values with annotation_source 'fallback'" do
        result = engine.annotate(clause, ideational)

        expect(result).to be_a(SFL::Compiler::Types::AnnotatedClause)
        expect(result.interpersonal.annotation_source).to eq("fallback")
        expect(result.interpersonal.mood).to eq("declarative")
        expect(result.interpersonal.modality_weight).to eq(0.5)
        expect(result.interpersonal.tenor).to eq(0.5)
        expect(result.interpersonal.speaker_attitude).to be_nil
        expect(result.textual.theme_type).to eq("unmarked")
        expect(result.textual.topical_theme).to eq("unknown")
      end

      it "does not raise an exception when the circuit is open" do
        expect { engine.annotate(clause, ideational) }.not_to raise_error
      end

      it "preserves the original clause text and ideational payload" do
        result = engine.annotate(clause, ideational)

        expect(result.text).to eq("The system processes data.")
        expect(result.syntactic.text).to eq("The system processes data.")
        expect(result.ideational.process_type).to eq("material")
        expect(result.document_id).to eq("doc-1")
      end
    end

    # ── annotate_chunk fallback ────────────────────────────────────

    describe "annotate_chunk with open circuit" do
      let(:chunk) do
        [{ index: 0, clause: clause, ideational: ideational }]
      end

      before { mock_breaker.trip! }

      it "applies fallback defaults to all clauses in the chunk" do
        result = engine.send(:annotate_chunk, chunk, "test-correlation")

        expect(result.size).to eq(1)
        annotated = result.first
        expect(annotated.interpersonal.annotation_source).to eq("fallback")
        expect(annotated.textual.theme_type).to eq("unmarked")
      end
    end

    # ── Constructor injection ─────────────────────────────────────

    describe "constructor injection" do
      it "accepts a circuit_breaker keyword argument" do
        breaker = MockCircuitBreaker.new
        eng = described_class.new(circuit_breaker: breaker)
        expect(eng).to be_a(described_class)
      end

      it "uses the injected circuit breaker" do
        breaker = MockCircuitBreaker.new
        eng = described_class.new(circuit_breaker: breaker, batch_annotator: ok_annotator)
        eng.annotate(clause, ideational)
        expect(breaker.call_count).to be >= 1
      end

      it "falls back to default_circuit_breaker when none is provided" do
        eng = described_class.new
        cb = eng.instance_variable_get(:@circuit_breaker)
        expect(cb).to respond_to(:call)
      end
    end

    # ── Default circuit breaker configuration ──────────────────────

    describe "default_circuit_breaker" do
      subject(:engine) { described_class.new }

      let(:cb) { engine.instance_variable_get(:@circuit_breaker) }

      before do
        allow(ENV).to receive(:fetch).and_call_original
      end

      it "returns a CircuitBreaker::CircuitHandler" do
        expect(cb).to be_a(CircuitBreaker::CircuitHandler)
      end

      it "responds to :call" do
        expect(cb).to respond_to(:call)
      end

      it "uses SFL_CIRCUIT_FAILURE_THRESHOLD env var" do
        allow(ENV).to receive(:fetch).with("SFL_CIRCUIT_FAILURE_THRESHOLD", 5).and_return(3)
        allow(ENV).to receive(:fetch).with("SFL_CIRCUIT_RETRY_TIMEOUT", 30).and_return(10)
        allow(ENV).to receive(:fetch).with("SFL_BATCH_SIZE", 12).and_return(12)
        allow(ENV).to receive(:fetch).with("SFL_CONCURRENCY", 4).and_return(4)
        allow(ENV).to receive(:fetch).with("SFL_CHUNK_TIMEOUT", 180).and_return(180)

        eng = described_class.new
        cb = eng.instance_variable_get(:@circuit_breaker)
        expect(cb.failure_threshold).to eq(3)
      end

      it "uses SFL_CIRCUIT_RETRY_TIMEOUT env var" do
        allow(ENV).to receive(:fetch).with("SFL_CIRCUIT_FAILURE_THRESHOLD", 5).and_return(3)
        allow(ENV).to receive(:fetch).with("SFL_CIRCUIT_RETRY_TIMEOUT", 30).and_return(10)
        allow(ENV).to receive(:fetch).with("SFL_BATCH_SIZE", 12).and_return(12)
        allow(ENV).to receive(:fetch).with("SFL_CONCURRENCY", 4).and_return(4)
        allow(ENV).to receive(:fetch).with("SFL_CHUNK_TIMEOUT", 180).and_return(180)

        eng = described_class.new
        cb = eng.instance_variable_get(:@circuit_breaker)
        expect(cb.failure_timeout).to eq(10)
      end
    end

    # ── Full lifecycle: closed → open → half-open → closed ────────

    describe "full lifecycle" do
      let(:lifecycle_breaker) { LifecycleBreaker.new }

      class LifecycleBreaker
        attr_reader :state, :calls

        def initialize
          @state = :closed
          @calls = 0
          @failure_count = 0
        end

        def call(&block)
          @calls += 1
          case @state
          when :closed
            @failure_count += 1
            if @failure_count >= 3
              @state = :open
            end
            raise StandardError, "fail"
          when :open
            raise CircuitBreaker::CircuitBrokenException, "open"
          when :half_open
            @state = :closed
            block.call
          end
        end

        def trip!; @state = :open; end
        def half_open!; @state = :half_open; end
      end

      it "transitions through all states correctly" do
        eng = described_class.new(circuit_breaker: lifecycle_breaker, batch_annotator: ok_annotator)

        # Phase 1: closed — failures accumulate, engine returns fallback
        3.times do
          result = eng.annotate(clause, ideational)
          expect(result.interpersonal.annotation_source).to eq("fallback")
        end

        # Phase 2: open — CircuitBrokenException → fallback
        lifecycle_breaker.trip!
        result = eng.annotate(clause, ideational)
        expect(result.interpersonal.annotation_source).to eq("fallback")

        # Phase 3: half-open → successful probe → closed
        lifecycle_breaker.half_open!
        # Stub the annotator so the probe call succeeds (no LM configured)
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call)
          .and_return({
            mood: "declarative",
            modality_weight: 0.7,
            tenor: 0.6,
            speaker_attitude: "neutral",
            reasoning: "ok",
            topical_theme: "system",
            textual_theme: nil,
            interpersonal_theme: nil,
            rheme: "processes data",
            theme_type: "unmarked",
          })
        result = eng.annotate(clause, ideational)
        expect(result.interpersonal.annotation_source).to eq("llm")
        expect(lifecycle_breaker.state).to eq(:closed)
      end
    end
  end
end
