# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::ConvergenceDetector do
  let(:embedder) { instance_double(SFL::Compiler::Embedder) }

  # Fixed embedding vectors for deterministic similarity tests.
  let(:vec_a) { [1.0, 0.0, 0.0] }
  let(:vec_b) { [1.0, 0.0, 0.0] }   # identical → similarity 1.0
  let(:vec_c) { [0.0, 1.0, 0.0] }   # orthogonal → similarity 0.0
  let(:vec_near) { [0.98, 0.199, 0.0].map { |v| v / Math.sqrt(0.98**2 + 0.199**2) } }  # cos ≈ 0.98

  describe "#check — first call" do
    it "never converges on the first call (no prior embedding)" do
      allow(embedder).to receive(:embed).and_return(vec_a)
      detector = described_class.new(embedder:, threshold: 0.97)

      result = detector.check("first summary")

      expect(result[:converged]).to be false
      expect(result[:similarity]).to be_nil
      expect(result[:cycles]).to eq(1)
    end
  end

  describe "#check — convergence above threshold" do
    it "returns converged: true when similarity >= threshold" do
      allow(embedder).to receive(:embed).and_return(vec_a, vec_b)
      detector = described_class.new(embedder:, threshold: 0.97)

      detector.check("cycle 1")
      result = detector.check("cycle 2")

      expect(result[:converged]).to be true
      expect(result[:similarity]).to be_within(0.001).of(1.0)
      expect(result[:cycles]).to eq(2)
    end
  end

  describe "#check — no convergence below threshold" do
    it "returns converged: false when similarity < threshold" do
      allow(embedder).to receive(:embed).and_return(vec_a, vec_c)
      detector = described_class.new(embedder:, threshold: 0.97)

      detector.check("cycle 1")
      result = detector.check("cycle 2")

      expect(result[:converged]).to be false
      expect(result[:similarity]).to be_within(0.001).of(0.0)
    end
  end

  describe "#check — threshold boundary" do
    it "does not converge just below threshold (0.96 < 0.97)" do
      # vec_near ≈ cosine 0.98 with vec_a, but we test near-miss
      low = [0.96, Math.sqrt(1 - 0.96**2), 0.0]
      allow(embedder).to receive(:embed).and_return(vec_a, low)
      detector = described_class.new(embedder:, threshold: 0.97)

      detector.check("a")
      result = detector.check("b")

      expect(result[:converged]).to be false
    end
  end

  describe "#check — embedder returns nil" do
    it "skips convergence check and returns converged: false" do
      allow(embedder).to receive(:embed).and_return(nil)
      detector = described_class.new(embedder:, threshold: 0.97)

      result = detector.check("can't embed this")

      expect(result[:converged]).to be false
      expect(result[:similarity]).to be_nil
    end
  end

  describe "checkpoint_every: N" do
    it "only checks on multiples of N (skips intermediate cycles)" do
      calls = [vec_a, vec_b, vec_b, vec_b]
      allow(embedder).to receive(:embed).and_return(*calls)
      detector = described_class.new(embedder:, threshold: 0.97, checkpoint_every: 2)

      r1 = detector.check("cycle 1")  # cycle 1: store embedding, no check
      r2 = detector.check("cycle 2")  # cycle 2: checkpoint → compare
      r3 = detector.check("cycle 3")  # cycle 3: not a checkpoint
      r4 = detector.check("cycle 4")  # cycle 4: checkpoint → compare

      expect(r1[:similarity]).to be_nil
      expect(r2[:similarity]).not_to be_nil
      expect(r3[:similarity]).to be_nil
      expect(r4[:similarity]).not_to be_nil
    end
  end

  describe "#reset!" do
    it "clears cycle count and prior embedding" do
      allow(embedder).to receive(:embed).and_return(vec_a, vec_b, vec_a)
      detector = described_class.new(embedder:, threshold: 0.97)

      detector.check("a")
      detector.check("b")
      detector.reset!

      expect(detector.cycles).to eq(0)
      result = detector.check("a again")
      expect(result[:similarity]).to be_nil  # no prior after reset
      expect(result[:cycles]).to eq(1)
    end
  end

  describe "#cycles and #last_similarity" do
    it "tracks cycle count across calls" do
      allow(embedder).to receive(:embed).and_return(vec_a, vec_c)
      detector = described_class.new(embedder:, threshold: 0.97)

      detector.check("x")
      detector.check("y")

      expect(detector.cycles).to eq(2)
      expect(detector.last_similarity).to be_within(0.001).of(0.0)
    end
  end
end
