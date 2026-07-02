# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::CitationGroundingChecker do
  subject(:checker) { described_class.new }

  def clause(id:, text:, document_id: "doc-1")
    { id: id, text: text, document_id: document_id }
  end

  let(:clauses) do
    [
      clause(id: "clause-1", text: "Speaker A expressed certainty about the decision.",
             document_id: "doc-1"),
      clause(id: "clause-2", text: "The tenor shifted noticeably between turns two and three.",
             document_id: "doc-1"),
      clause(id: "clause-3", text: "Modal verbs indicate hedging and epistemic distance.",
             document_id: "doc-1")
    ]
  end

  describe "#check" do
    context "when all claims are cited and grounded (100% coverage)" do
      let(:narrative) do
        "Speaker A expressed certainty and decision-making confidence [clause-1]. " \
        "The tenor shifted noticeably across turns [clause-2]. " \
        "Modal verbs indicate hedging distance and uncertainty [clause-3]."
      end

      it "returns coverage of 1.0 with no ungrounded claims" do
        result = checker.check(narrative, clauses)

        expect(result[:coverage]).to eq(1.0)
        expect(result[:ungrounded]).to be_empty
        expect(result[:grounded].size).to eq(3)
      end
    end

    context "when some claims are invented (no citation marker)" do
      let(:narrative) do
        "Speaker A expressed certainty and decision-making [clause-1]. " \
        "The conversation escalated dramatically with rising tension. " \
        "Modal verbs indicate hedging uncertainty and distance [clause-3]."
      end

      it "flags the uncited claim as ungrounded" do
        result = checker.check(narrative, clauses)

        expect(result[:ungrounded].size).to eq(1)
        expect(result[:ungrounded].first[:reason]).to match(/no citation marker/i)
        expect(result[:ungrounded].first[:sentence]).to include("escalated")
        expect(result[:coverage]).to be_within(0.001).of(2.0 / 3)
      end
    end

    context "when a citation points to a non-existent clause_id" do
      let(:narrative) do
        "Speaker A expressed certainty and decision-making [clause-1]. " \
        "Speaker A showed extreme hostility and aggression [fake-clause-99]."
      end

      it "detects the invalid citation as ungrounded" do
        result = checker.check(narrative, clauses)

        ungrounded = result[:ungrounded]
        expect(ungrounded.size).to eq(1)
        expect(ungrounded.first[:reason]).to match(/clause not found/i)
        expect(ungrounded.first[:citations]).to include("fake-clause-99")
        expect(result[:coverage]).to eq(0.5)
      end
    end

    context "with compound doc:id citation style" do
      let(:narrative) do
        "Speaker A expressed certainty and decision-making [doc-1:clause-1]."
      end

      it "resolves compound doc:id references correctly" do
        result = checker.check(narrative, clauses)
        expect(result[:grounded].size).to eq(1)
        expect(result[:ungrounded]).to be_empty
      end
    end

    context "when citation exists but no keyword overlap" do
      let(:narrative) do
        "The weather was pleasant and sunny today [clause-1]."
      end

      it "flags the sentence as ungrounded due to missing keyword overlap" do
        result = checker.check(narrative, clauses)
        expect(result[:ungrounded].size).to eq(1)
        expect(result[:ungrounded].first[:reason]).to match(/keyword overlap/i)
      end
    end

    context "with empty narrative" do
      it "returns coverage 0.0 and empty lists for blank text" do
        result = checker.check("", clauses)
        expect(result[:coverage]).to eq(0.0)
        expect(result[:grounded]).to be_empty
        expect(result[:ungrounded]).to be_empty
      end
    end

    context "with empty source clauses" do
      let(:narrative) { "Speaker expressed certainty [clause-1]." }

      it "treats all citations as ungrounded (no index)" do
        result = checker.check(narrative, [])
        expect(result[:ungrounded].size).to eq(1)
        expect(result[:ungrounded].first[:reason]).to match(/clause not found/i)
      end
    end

    context "simulating 20-claim narrative with 2 invented claims (90% acceptance)" do
      let(:cited_sentences) do
        (1..18).map do |i|
          "Speaker expressed certainty and confidence about decision #{i} [clause-1]."
        end
      end

      let(:invented_sentences) do
        [
          "The participants engaged in dramatic confrontation and hostile escalation.",
          "Unprecedented tension emerged throughout the entire discussion here."
        ]
      end

      let(:narrative) { (cited_sentences + invented_sentences).join(" ") }

      it "achieves 90% coverage with exactly 2 ungrounded claims" do
        result = checker.check(narrative, clauses)

        expect(result[:grounded].size).to eq(18)
        expect(result[:ungrounded].size).to eq(2)
        expect(result[:coverage]).to be_within(0.001).of(0.9)
        expect(result[:ungrounded].all? { |u| u[:reason] == "no citation marker" }).to be true
      end
    end
  end
end
