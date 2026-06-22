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

      it "maps 'topical_unmarked' to 'unmarked'" do
        result = { theme_type: "topical_unmarked", topical_theme: "Test", rheme: "clause" }
        payload = engine.send(:textual_from, clause, result, correlation_id)
        expect(payload.theme_type).to eq("unmarked")
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

    describe "#normalize_theme_type" do
      it "fixes 'topual' to 'topical'" do
        expect(engine.send(:normalize_theme_type, "topual")).to eq("topical")
      end

      it "handles compound types with plus sign" do
        expect(engine.send(:normalize_theme_type, "textual + topical")).to eq("textual")
        expect(engine.send(:normalize_theme_type, "interpersonal+marked")).to eq("interpersonal")
      end

      it "maps 'topical_unmarked' to 'unmarked'" do
        expect(engine.send(:normalize_theme_type, "topical_unmarked")).to eq("unmarked")
      end

      it "handles case insensitivity" do
        expect(engine.send(:normalize_theme_type, "INTERJECTION")).to eq("interjection")
        expect(engine.send(:normalize_theme_type, "InterPersonal")).to eq("interpersonal")
      end

      it "handles whitespace" do
        expect(engine.send(:normalize_theme_type, "  interjection  ")).to eq("interjection")
      end

      it "returns 'unmarked' for nil input" do
        expect(engine.send(:normalize_theme_type, nil)).to eq("unmarked")
      end

      it "passes through valid types unchanged" do
        %w[unmarked marked interrogative imperative].each do |type|
          expect(engine.send(:normalize_theme_type, type)).to eq(type)
        end
      end
    end

    describe "#normalize_mood" do
      it "maps 'exclamatory' to 'exclamative'" do
        expect(engine.send(:normalize_mood, "exclamatory")).to eq("exclamative")
      end

      it "maps clause-rank/no-mood vocabulary to 'fragment'" do
        expect(engine.send(:normalize_mood, "non-finite")).to eq("fragment")
        expect(engine.send(:normalize_mood, "none")).to eq("fragment")
      end

      it "maps any Group-rank '*_phrase' value to 'fragment'" do
        expect(engine.send(:normalize_mood, "nominal_phrase")).to eq("fragment")
        expect(engine.send(:normalize_mood, "prepositional_phrase")).to eq("fragment")
      end

      it "handles case insensitivity and whitespace" do
        expect(engine.send(:normalize_mood, "  EXCLAMATORY  ")).to eq("exclamative")
      end

      it "returns 'declarative' for nil or empty input" do
        expect(engine.send(:normalize_mood, nil)).to eq("declarative")
        expect(engine.send(:normalize_mood, "")).to eq("declarative")
      end

      it "passes through valid moods unchanged" do
        SFL::Compiler::Types::MoodType.each_value do |mood|
          expect(engine.send(:normalize_mood, mood)).to eq(mood)
        end
      end
    end
  end
end
