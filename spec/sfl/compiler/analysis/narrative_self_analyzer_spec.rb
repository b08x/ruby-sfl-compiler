# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::NarrativeSelfAnalyzer do
  def mock_clause(tenor:, modality:, mood:)
    inter = double("InterpersonalPayload",
      tenor: tenor,
      modality_weight: modality,
      mood: mood)
    double("AnnotatedClause", interpersonal: inter)
  end

  def mock_result(clauses)
    turn = double("ConversationTurn", clauses: clauses)
    double("AnalysisResult", turns: [turn])
  end

  describe "#analyze" do
    context "(a) narrative matching the source profile" do
      it "scores < 0.1 divergence and is not flagged" do
        source_clauses = Array.new(5) { mock_clause(tenor: 0.5, modality: 0.5, mood: "declarative") }
        source = mock_result(source_clauses)

        narrative_clauses = Array.new(3) { mock_clause(tenor: 0.5, modality: 0.5, mood: "declarative") }
        pipeline = instance_double(SFL::Compiler::Pipeline)
        allow(pipeline).to receive(:compile).and_return(narrative_clauses)

        result = described_class.new(pipeline:).analyze("The narrative text.", source_result: source)

        expect(result.strange_loop_divergence).to be < 0.1
        expect(result.flagged).to be false
        expect(result.error).to be_nil
      end
    end

    context "(b) narrative with invented escalating tension in a flat conversation" do
      it "scores > 0.3 divergence and is flagged" do
        source_clauses = Array.new(5) { mock_clause(tenor: 0.3, modality: 0.4, mood: "declarative") }
        source = mock_result(source_clauses)

        narrative_clauses = [
          mock_clause(tenor: 0.9, modality: 0.85, mood: "imperative"),
          mock_clause(tenor: 0.95, modality: 0.9,  mood: "exclamative"),
          mock_clause(tenor: 0.85, modality: 0.8,  mood: "imperative")
        ]
        pipeline = instance_double(SFL::Compiler::Pipeline)
        allow(pipeline).to receive(:compile).and_return(narrative_clauses)

        result = described_class.new(pipeline:).analyze(
          "The tension escalated dramatically throughout!", source_result: source
        )

        expect(result.strange_loop_divergence).to be > 0.3
        expect(result.flagged).to be true
      end
    end

    context "(c) empty narrative" do
      it "returns divergence=1.0 with error flag without calling the pipeline" do
        source = mock_result([])
        pipeline = instance_double(SFL::Compiler::Pipeline)
        expect(pipeline).not_to receive(:compile)

        result = described_class.new(pipeline:).analyze("   ", source_result: source)

        expect(result.strange_loop_divergence).to eq(1.0)
        expect(result.flagged).to be true
        expect(result.error).to eq("empty narrative")
      end
    end

    context "when pipeline returns no clauses" do
      it "returns divergence=1.0 with a pipeline error" do
        source = mock_result([mock_clause(tenor: 0.5, modality: 0.5, mood: "declarative")])
        pipeline = instance_double(SFL::Compiler::Pipeline)
        allow(pipeline).to receive(:compile).and_return([])

        result = described_class.new(pipeline:).analyze("some text", source_result: source)

        expect(result.strange_loop_divergence).to eq(1.0)
        expect(result.flagged).to be true
        expect(result.error).to eq("pipeline produced no clauses")
      end
    end

    context "when source result has no turns" do
      it "treats source as zero profile and flags divergence from non-zero narrative" do
        source = double("AnalysisResult", turns: [])
        narrative_clauses = [mock_clause(tenor: 0.6, modality: 0.6, mood: "declarative")]
        pipeline = instance_double(SFL::Compiler::Pipeline)
        allow(pipeline).to receive(:compile).and_return(narrative_clauses)

        result = described_class.new(pipeline:).analyze("narrative text", source_result: source)

        expect(result.source_profile[:avg_tenor]).to eq(0.0)
        expect(result.tenor_delta).to be_within(0.001).of(0.6)
        expect(result.flagged).to be true
      end
    end

    it "exposes narrative and source profiles in the result" do
      source_clauses = [mock_clause(tenor: 0.4, modality: 0.6, mood: "interrogative")]
      source = mock_result(source_clauses)

      narrative_clauses = [mock_clause(tenor: 0.7, modality: 0.3, mood: "declarative")]
      pipeline = instance_double(SFL::Compiler::Pipeline)
      allow(pipeline).to receive(:compile).and_return(narrative_clauses)

      result = described_class.new(pipeline:).analyze("some text", source_result: source)

      expect(result.narrative_profile[:avg_tenor]).to be_within(0.001).of(0.7)
      expect(result.source_profile[:avg_tenor]).to be_within(0.001).of(0.4)
      expect(result.narrative_profile[:mood_distribution]).to eq("declarative" => 1.0)
      expect(result.source_profile[:mood_distribution]).to eq("interrogative" => 1.0)
    end
  end
end
