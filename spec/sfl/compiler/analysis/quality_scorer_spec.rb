# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::QualityScorer do
  subject(:scorer) { described_class.new }

  describe "#score" do
    it "returns 0.0 for empty clauses" do
      expect(scorer.score(clauses: [])).to eq(0.0)
    end

    it "returns a value in [0.0, 1.0] for any input" do
      clauses = Array.new(25) { make_clause(annotation_source: "llm", modality_weight: 1.0) }
      score = scorer.score(clauses:, last_updated: Time.now)
      expect(score).to be_between(0.0, 1.0).inclusive
    end

    context "annotation source weight" do
      it "produces a high score for all-llm clauses" do
        clauses = Array.new(10) { make_clause(annotation_source: "llm", modality_weight: 0.7) }
        expect(scorer.score(clauses:)).to be > 0.55
      end

      it "produces a lower score for all-fallback clauses" do
        clauses_llm      = Array.new(10) { make_clause(annotation_source: "llm",      modality_weight: 0.7) }
        clauses_fallback = Array.new(10) { make_clause(annotation_source: "fallback", modality_weight: 0.7) }
        expect(scorer.score(clauses: clauses_llm)).to be > scorer.score(clauses: clauses_fallback)
      end

      it "stubs score lower than fallback" do
        clauses_stub     = Array.new(5) { make_clause(annotation_source: "stub",     modality_weight: 0.5) }
        clauses_fallback = Array.new(5) { make_clause(annotation_source: "fallback", modality_weight: 0.5) }
        expect(scorer.score(clauses: clauses_stub)).to be < scorer.score(clauses: clauses_fallback)
      end
    end

    context "modality weight contribution" do
      it "scores higher when clauses have higher modality" do
        low  = Array.new(5) { make_clause(modality_weight: 0.1, annotation_source: "llm") }
        high = Array.new(5) { make_clause(modality_weight: 0.9, annotation_source: "llm") }
        expect(scorer.score(clauses: high)).to be > scorer.score(clauses: low)
      end
    end

    context "substance (clause count)" do
      it "scores higher with more clauses (up to ceiling)" do
        few  = Array.new(2)  { make_clause(annotation_source: "llm", modality_weight: 0.6) }
        many = Array.new(20) { make_clause(annotation_source: "llm", modality_weight: 0.6) }
        expect(scorer.score(clauses: many)).to be > scorer.score(clauses: few)
      end

      it "does not exceed 1.0 even with many clauses and high modality" do
        clauses = Array.new(50) { make_clause(annotation_source: "llm", modality_weight: 1.0) }
        expect(scorer.score(clauses:, last_updated: Time.now)).to be <= 1.0
      end
    end

    context "freshness" do
      let(:base_clauses) do
        Array.new(10) { make_clause(annotation_source: "llm", modality_weight: 0.7) }
      end

      it "scores fresh content higher than stale content" do
        fresh = Time.now
        stale = Time.now - (2 * 365 * 24 * 60 * 60)  # 2 years ago
        expect(scorer.score(clauses: base_clauses, last_updated: fresh))
          .to be > scorer.score(clauses: base_clauses, last_updated: stale)
      end

      it "treats nil last_updated as a neutral freshness (0.5 contribution)" do
        fresh_score = scorer.score(clauses: base_clauses, last_updated: Time.now)
        nil_score   = scorer.score(clauses: base_clauses, last_updated: nil)
        stale_score = scorer.score(clauses: base_clauses, last_updated: Time.now - (3 * 365 * 24 * 60 * 60))

        # nil is between fresh and stale
        expect(nil_score).to be < fresh_score
        expect(nil_score).to be > stale_score
      end

      it "clamps freshness to 0.0 for very old content (beyond cutoff)" do
        ancient = Time.now - (5 * 365 * 24 * 60 * 60)  # 5 years ago
        score = scorer.score(clauses: base_clauses, last_updated: ancient)
        expect(score).to be >= 0.0
        expect(score).to be <= 1.0
      end
    end
  end
end
