# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::PassTwoEngine do
  subject(:engine) { described_class.new }

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

  describe "#annotate" do
    context "when DSPy succeeds" do
      it "returns an AnnotatedClause with the DSPy result" do
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call)
          .and_return({
            mood: "declarative",
            modality_weight: 0.8,
            tenor: 0.7,
            speaker_attitude: "assertive",
            reasoning: "Formal declarative with strong certainty",
          })

        result = engine.annotate(clause, ideational)

        expect(result).to be_a(SFL::Compiler::Types::AnnotatedClause)
        expect(result.text).to eq("The system processes data.")
        expect(result.interpersonal.mood).to eq("declarative")
        expect(result.interpersonal.modality_weight).to eq(0.8)
        expect(result.interpersonal.tenor).to eq(0.7)
        expect(result.interpersonal.speaker_attitude).to eq("assertive")
      end
    end

    context "when DSPy raises StandardError" do
      it "returns an AnnotatedClause with default interpersonal values" do
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call)
          .and_raise(StandardError, "OpenRouter API timeout")

        result = engine.annotate(clause, ideational)

        expect(result).to be_a(SFL::Compiler::Types::AnnotatedClause)
        expect(result.interpersonal.modality_weight).to eq(0.5)
        expect(result.interpersonal.tenor).to eq(0.5)
        expect(result.interpersonal.mood).to eq("declarative")
        expect(result.interpersonal.speaker_attitude).to be_nil
      end

      it "logs a visible warning to stderr" do
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call)
          .and_raise(StandardError, "LLM connection refused")

        expect { engine.annotate(clause, ideational) }
          .to output(
            /\[WARN\] Pass 2 \(clause-1\): DSPy annotation failed: LLM connection refused/
          ).to_stderr
      end

      it "still produces a valid syntactic + ideational payload" do
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call)
          .and_raise(StandardError, "fail")

        result = engine.annotate(clause, ideational)

        expect(result.syntactic.text).to eq("The system processes data.")
        expect(result.ideational.process_type).to eq("material")
        expect(result.ideational.participants).to eq([])
        expect(result.document_id).to eq("doc-1")
      end
    end

    context "when circuit breaker is tripped" do
      let(:tripped_breaker) do
        Class.new do
          def call
            raise CircuitBreaker::CircuitBrokenException, "Circuit open"
          end
        end.new
      end

      subject(:engine_with_tripped) { described_class.new(circuit_breaker: tripped_breaker) }

      it "returns defaults with circuit-open reasoning" do
        result = engine_with_tripped.annotate(clause, ideational)

        expect(result).to be_a(SFL::Compiler::Types::AnnotatedClause)
        expect(result.interpersonal.modality_weight).to eq(0.5)
        expect(result.interpersonal.tenor).to eq(0.5)
        expect(result.interpersonal.mood).to eq("declarative")
      end
    end

    describe "reasoning_trace bridge" do
      def dspy_response(premises:, inference_rule: "tenor_high_formal_register")
        {
          mood: "declarative", modality_weight: 0.8, tenor: 0.7,
          speaker_attitude: "assertive", reasoning: "formal register",
          premises:, inference_rule:,
        }
      end

      let(:premises) do
        [
          SFL::Compiler::PremiseOutput.new(type: "token", source: "unanimously", value: "ADV", weight: 0.7),
          SFL::Compiler::PremiseOutput.new(type: "pos", source: "DET+VERB", value: "formal_pattern", weight: nil),
        ]
      end

      it "attaches a reasoning_trace to llm-sourced annotations" do
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call).and_return(dspy_response(premises:))

        result = engine.annotate(clause, ideational)

        trace = result.interpersonal.reasoning_trace
        expect(trace).to be_a(SFL::Compiler::Types::ReasoningTrace)
        expect(trace.premises.size).to eq(2)
        expect(trace.inference_rule).to eq("tenor_high_formal_register")
      end

      it "leaves mood/tenor/modality untouched and only nils reasoning_trace when a premise is malformed" do
        bad_premise = double("BadPremise", type: "token", source: "x", value: "y", weight: "not-a-float")
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call).and_return(dspy_response(premises: [bad_premise]))

        result = nil
        expect { result = engine.annotate(clause, ideational) }.to output(/\[WARN\].*reasoning trace/).to_stderr

        expect(result.interpersonal.annotation_source).to eq("llm")
        expect(result.interpersonal.mood).to eq("declarative")
        expect(result.interpersonal.tenor).to eq(0.7)
        expect(result.interpersonal.reasoning_trace).to be_nil
      end

      it "leaves reasoning_trace nil for fallback-sourced (non-LLM) annotations" do
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call).and_raise(StandardError, "boom")

        result = nil
        expect { result = engine.annotate(clause, ideational) }.to output(/\[WARN\]/).to_stderr

        expect(result.interpersonal.annotation_source).to eq("fallback")
        expect(result.interpersonal.reasoning_trace).to be_nil
      end

      it "produces a byte-identical derivation_hash for two calls with identical DSPy responses" do
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call).and_return(dspy_response(premises:))

        first = engine.annotate(clause, ideational).interpersonal.reasoning_trace.derivation_hash
        second = engine.annotate(clause, ideational).interpersonal.reasoning_trace.derivation_hash

        expect(first).to eq(second)
      end

      it "produces a different derivation_hash when the conclusion differs, same premises" do
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call).and_return(dspy_response(premises:))
        hash_a = engine.annotate(clause, ideational).interpersonal.reasoning_trace.derivation_hash

        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call).and_return(dspy_response(premises:).merge(tenor: 0.1))
        hash_b = engine.annotate(clause, ideational).interpersonal.reasoning_trace.derivation_hash

        expect(hash_a).not_to eq(hash_b)
      end

      it "is order-independent: premises in a different array order still hash the same" do
        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call).and_return(dspy_response(premises:))
        hash_a = engine.annotate(clause, ideational).interpersonal.reasoning_trace.derivation_hash

        allow_any_instance_of(SFL::Compiler::SFLAnnotator)
          .to receive(:call).and_return(dspy_response(premises: premises.reverse))
        hash_b = engine.annotate(clause, ideational).interpersonal.reasoning_trace.derivation_hash

        expect(hash_a).to eq(hash_b)
      end
    end

    describe "SFL::Compiler::SFLAnnotator#call" do
      it "passes structured premises and inference_rule through as PremiseOutput instances" do
        premises = [
          SFL::Compiler::PremiseOutput.new(type: "token", source: "unanimously", value: "ADV", weight: 0.7),
          SFL::Compiler::PremiseOutput.new(type: "pos", source: "DET+VERB", value: "formal_pattern", weight: nil),
        ]
        dspy_result = double(
          mood: "declarative", modality_weight: 0.8, tenor: 0.7,
          speaker_attitude: "assertive", topical_theme: "The system",
          textual_theme: nil, interpersonal_theme: nil, rheme: "processes data",
          theme_type: "unmarked", reasoning: "formal register",
          premises:, inference_rule: "tenor_high_formal_register"
        )
        predictor = instance_double(DSPy::ChainOfThought, call: dspy_result)
        allow(DSPy::ChainOfThought).to receive(:new).and_return(predictor)

        result = SFL::Compiler::SFLAnnotator.new("Text: test\n").call

        expect(result[:premises]).to eq(premises)
        expect(result[:premises].first).to be_a(SFL::Compiler::PremiseOutput)
        expect(result[:premises].first.type).to eq("token")
        expect(result[:inference_rule]).to eq("tenor_high_formal_register")
      end
    end

    describe "#interpersonal_from" do
      let(:correlation_id) { "test-correlation" }

      it "normalizes 'exclamatory' to 'exclamative'" do
        result = { mood: "exclamatory", modality_weight: 0.5, tenor: 0.5 }
        payload = engine.send(:interpersonal_from, clause, result, correlation_id)
        expect(payload.mood).to eq("exclamative")
        expect(payload.annotation_source).to eq("llm")
      end

      it "normalizes 'non-finite' to 'fragment'" do
        result = { mood: "non-finite", modality_weight: 0.5, tenor: 0.5 }
        payload = engine.send(:interpersonal_from, clause, result, correlation_id)
        expect(payload.mood).to eq("fragment")
      end

      it "normalizes 'none' to 'fragment'" do
        result = { mood: "none", modality_weight: 0.5, tenor: 0.5 }
        payload = engine.send(:interpersonal_from, clause, result, correlation_id)
        expect(payload.mood).to eq("fragment")
      end

      it "normalizes any '*_phrase' value to 'fragment'" do
        %w[nominal_phrase prepositional_phrase verbal_phrase].each do |mood|
          result = { mood:, modality_weight: 0.5, tenor: 0.5 }
          payload = engine.send(:interpersonal_from, clause, result, correlation_id)
          expect(payload.mood).to eq("fragment")
        end
      end

      it "preserves modality_weight/tenor/reasoning when mood needed normalizing" do
        result = { mood: "none", modality_weight: 0.9, tenor: 0.3, reasoning: "real LLM reasoning" }
        payload = engine.send(:interpersonal_from, clause, result, correlation_id)
        expect(payload.modality_weight).to eq(0.9)
        expect(payload.tenor).to eq(0.3)
        expect(payload.reasoning).to eq("real LLM reasoning")
      end

      it "passes through valid moods unchanged" do
        SFL::Compiler::Types::MoodType.each_value do |mood|
          result = { mood:, modality_weight: 0.5, tenor: 0.5 }
          payload = engine.send(:interpersonal_from, clause, result, correlation_id)
          expect(payload.mood).to eq(mood)
        end
      end
    end

    describe "#textual_from" do
      let(:correlation_id) { "test-correlation" }

      it "normalizes 'topual' typo to 'topical'" do
        result = { theme_type: "topual", topical_theme: "Test", rheme: "clause" }
        payload = engine.send(:textual_from, clause, result, correlation_id)
        expect(payload.theme_type).to eq("topical")
      end

      it "handles compound types like 'textual + topical'" do
        result = { theme_type: "textual + topical", topical_theme: "Test", rheme: "clause" }
        payload = engine.send(:textual_from, clause, result, correlation_id)
        expect(payload.theme_type).to eq("textual")
      end

      it "maps 'topical_unmarked' to 'topical'" do
        result = { theme_type: "topical_unmarked", topical_theme: "Test", rheme: "clause" }
        payload = engine.send(:textual_from, clause, result, correlation_id)
        expect(payload.theme_type).to eq("topical")
      end

      it "accepts new valid types 'interjection' and 'interpersonal'" do
        %w[interjection interpersonal].each do |theme_type|
          result = { theme_type:, topical_theme: "Test", rheme: "clause" }
          payload = engine.send(:textual_from, clause, result, correlation_id)
          expect(payload.theme_type).to eq(theme_type)
        end
      end

      it "handles nil theme_type by defaulting to 'unmarked'" do
        result = { theme_type: nil, topical_theme: "Test", rheme: "clause" }
        payload = engine.send(:textual_from, clause, result, correlation_id)
        expect(payload.theme_type).to eq("unmarked")
      end

      it "handles empty string theme_type by defaulting to 'unmarked'" do
        result = { theme_type: "", topical_theme: "Test", rheme: "clause" }
        payload = engine.send(:textual_from, clause, result, correlation_id)
        expect(payload.theme_type).to eq("unmarked")
      end
    end

    describe "SFL::Compiler::ClassificationRegistry.normalize(:theme_type)" do
      it "fixes 'topual' to 'topical'" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, "topual").first).to eq("topical")
      end

      it "handles compound types with plus sign" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, "textual + topical").first).to eq("textual")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type,
          "interpersonal+marked").first).to eq("interpersonal")
      end

      it "maps 'topical_unmarked' to 'topical'" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, "topical_unmarked").first).to eq("topical")
      end

      it "handles case insensitivity" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, "INTERJECTION").first).to eq("interjection")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type,
          "InterPersonal").first).to eq("interpersonal")
      end

      it "handles whitespace" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type,
          "  interjection  ").first).to eq("interjection")
      end

      it "strips the 'theme_' prefix and '_theme' suffix if present" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, "theme_unmarked").first).to eq("unmarked")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, "theme_marked").first).to eq("marked")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type,
          "theme_interrogative").first).to eq("interrogative")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, "topical_theme").first).to eq("topical")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, "textual theme").first).to eq("textual")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type,
          "theme_interpersonal_theme").first).to eq("interpersonal")
      end

      it "returns 'unmarked' for nil input" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, nil).first).to eq("unmarked")
      end

      it "passes through valid types unchanged" do
        %w[unmarked marked interrogative imperative].each do |type|
          expect(SFL::Compiler::ClassificationRegistry.normalize(:theme_type, type).first).to eq(type)
        end
      end
    end

    describe "SFL::Compiler::ClassificationRegistry.normalize(:mood)" do
      it "maps 'exclamatory' to 'exclamative'" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "exclamatory").first).to eq("exclamative")
      end

      it "maps question synonyms to 'interrogative'" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "question").first).to eq("interrogative")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "questions").first).to eq("interrogative")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "query").first).to eq("interrogative")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "queries").first).to eq("interrogative")
      end

      it "maps clause-rank/no-mood vocabulary to 'fragment'" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "non-finite").first).to eq("fragment")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "none").first).to eq("fragment")
      end

      it "maps any Group-rank '*_phrase' value to 'fragment'" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "nominal_phrase").first).to eq("fragment")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "prepositional_phrase").first).to eq("fragment")
      end

      it "handles case insensitivity and whitespace" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "  EXCLAMATORY  ").first).to eq("exclamative")
      end

      it "returns 'declarative' for nil or empty input" do
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, nil).first).to eq("declarative")
        expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, "").first).to eq("declarative")
      end

      it "passes through valid moods unchanged" do
        SFL::Compiler::Types::MoodType.each_value do |mood|
          expect(SFL::Compiler::ClassificationRegistry.normalize(:mood, mood).first).to eq(mood)
        end
      end
    end
  end

  describe "#annotate_batch with CognitiveGas circuit breaker" do
    let(:stub_annotation) do
      lambda { |items|
        items.map { |item|
          { index: item[:index], mood: "declarative", modality_weight: 0.5, tenor: 0.5,
            speaker_attitude: "neutral", reasoning: "ok", premises: [], inference_rule: nil,
            topical_theme: "The", textual_theme: nil, interpersonal_theme: nil, rheme: "rest",
            theme_type: "unmarked" }
        }
      }
    end

    it "charges batch cost before the LLM call when gas responds to charge_batch" do
      fresh_gas = SFL::Compiler::CognitiveGas.new(budget: 1_000)
      engine_with_gas = described_class.new(
        circuit_breaker: fresh_gas,
        batch_annotator: stub_annotation
      )

      engine_with_gas.annotate_batch([[clause, ideational]])

      expect(fresh_gas.spent).to be > 0
    end

    it "resets the gas budget and continues processing when budget is exhausted" do
      exhausted_gas = SFL::Compiler::CognitiveGas.new(budget: 0)
      engine = described_class.new(
        circuit_breaker: exhausted_gas,
        batch_annotator: stub_annotation
      )

      results = engine.annotate_batch([[clause, ideational]])

      expect(results.size).to eq(1)
      expect(exhausted_gas.spent).to be >= 0
    end

    it "calls on_gas_exhausted with clause IDs when budget is exhausted" do
      exhausted_gas = SFL::Compiler::CognitiveGas.new(budget: 0)
      captured_ids = nil
      engine = described_class.new(
        circuit_breaker: exhausted_gas,
        batch_annotator: stub_annotation,
        on_gas_exhausted: ->(ids) { captured_ids = ids }
      )

      engine.annotate_batch([[clause, ideational]])

      expect(captured_ids).to include(clause.id)
    end

    it "does not call on_gas_exhausted when budget is sufficient" do
      fresh_gas = SFL::Compiler::CognitiveGas.new(budget: 1_000)
      callback_called = false
      engine = described_class.new(
        circuit_breaker: fresh_gas,
        batch_annotator: stub_annotation,
        on_gas_exhausted: ->(_ids) { callback_called = true }
      )

      engine.annotate_batch([[clause, ideational]])

      expect(callback_called).to be false
    end

    it "continues annotating remaining clauses after a gas reset" do
      # Budget that exhausts after first chunk, refills, allows second
      gas = SFL::Compiler::CognitiveGas.new(budget: 0)
      engine = described_class.new(
        circuit_breaker: gas,
        batch_annotator: stub_annotation,
        on_gas_exhausted: ->(_ids) {}
      )

      results = engine.annotate_batch([[clause, ideational], [clause, ideational]], batch_size: 1)

      expect(results.size).to eq(2)
    end
  end
end
