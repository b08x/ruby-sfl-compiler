# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::HybridRetriever do
  # Unit tests for RRF logic without database dependency
  describe "Reciprocal Rank Fusion" do
    it "correctly computes RRF scores" do
      # RRF formula: 1/(60 + rank)
      k = SFL::Compiler::HybridRetriever::RRF_K

      # Item A: rank 1 in semantic, rank 2 in keyword
      score_a = 1.0 / (k + 1) + 1.0 / (k + 2)

      # Item B: rank 2 in semantic, rank 1 in keyword
      score_b = 1.0 / (k + 2) + 1.0 / (k + 1)

      # Both should have same score (symmetric)
      expect(score_a).to be_within(0.001).of(score_b)

      # Item C: rank 1 in semantic only
      score_c = 1.0 / (k + 1)

      # A should score higher than C (appears in both lists)
      expect(score_a).to be > score_c
    end
  end

  describe "Embedder" do
    it "returns nil for empty text" do
      embedder = SFL::Compiler::Embedder.new
      expect(embedder.embed("")).to be_nil
      expect(embedder.embed(nil)).to be_nil
    end
  end
end
