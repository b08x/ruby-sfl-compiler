# frozen_string_literal: true

require "spec_helper"

# End-to-end stuck-loop test for ConvergenceDetector.
#
# Demonstrates the halt pattern: a reasoning loop that rephrases the same
# argument across cycles MUST be detected and stopped within a bounded number
# of cycles — an infinite loop is structurally impossible when the detector
# is wired as the loop's halt predicate.
RSpec.describe "Semantic convergence stuck-loop halt" do
  # Identical embedding returned every cycle — simulates a loop that rephrases
  # the same argument without adding new information.
  let(:fixed_vector) { [1.0, 0.0, 0.0] }
  let(:embedder) do
    e = instance_double(SFL::Compiler::Embedder)
    allow(e).to receive(:embed).and_return(fixed_vector)
    e
  end

  let(:detector) do
    SFL::Compiler::ConvergenceDetector.new(
      embedder:,
      threshold: 0.97,
      checkpoint_every: 1
    )
  end

  MAX_CYCLES = 10   # hard upper bound; no test should ever reach this

  def simulate_synthesis_loop(detector, max_cycles: MAX_CYCLES)
    cycles_run = 0
    final_result = nil

    loop do
      cycles_run += 1
      summary = "The system processes data efficiently. (cycle #{cycles_run})"
      final_result = detector.check(summary, clauses_consumed: cycles_run * 5)

      break if final_result[:converged]
      break if cycles_run >= max_cycles   # safety guard
    end

    { cycles_run:, final_result: }
  end

  describe "loop termination" do
    it "halts within 2 cycles when embeddings are identical" do
      outcome = simulate_synthesis_loop(detector)

      expect(outcome[:cycles_run]).to be <= 2
      expect(outcome[:final_result][:converged]).to be true
    end

    it "never exceeds MAX_CYCLES (infinite loop impossible)" do
      outcome = simulate_synthesis_loop(detector, max_cycles: MAX_CYCLES)

      expect(outcome[:cycles_run]).to be < MAX_CYCLES
    end

    it "reports similarity of 1.0 on convergence (identical embeddings)" do
      outcome = simulate_synthesis_loop(detector)

      expect(outcome[:final_result][:similarity]).to be_within(0.001).of(1.0)
    end

    it "records the correct cycle count at halt" do
      outcome = simulate_synthesis_loop(detector)

      # Cycle 1: no prior embedding — stores, no comparison
      # Cycle 2: compares against cycle 1 — converges
      expect(outcome[:cycles_run]).to eq(2)
      expect(outcome[:final_result][:cycles]).to eq(2)
    end
  end

  describe "loop with gradual convergence (checkpoint_every: 2)" do
    let(:detector_sampled) do
      SFL::Compiler::ConvergenceDetector.new(
        embedder:,
        threshold: 0.97,
        checkpoint_every: 2
      )
    end

    it "halts within 4 cycles when only checking every other cycle" do
      outcome = simulate_synthesis_loop(detector_sampled, max_cycles: MAX_CYCLES)

      expect(outcome[:cycles_run]).to be <= 4
      expect(outcome[:final_result][:converged]).to be true
    end
  end

  describe "reset! allows a fresh loop to converge independently" do
    it "treats a reset detector as a new loop with no memory of prior cycles" do
      # First loop — runs to convergence
      simulate_synthesis_loop(detector)
      expect(detector.cycles).to be > 0

      # Reset — should start fresh
      detector.reset!
      expect(detector.cycles).to eq(0)

      # Second loop — must still converge within 2 cycles
      outcome = simulate_synthesis_loop(detector)
      expect(outcome[:cycles_run]).to be <= 2
      expect(outcome[:final_result][:converged]).to be true
    end
  end

  describe "last_similarity attribute after halt" do
    it "exposes the final similarity score for audit logging" do
      simulate_synthesis_loop(detector)

      expect(detector.last_similarity).not_to be_nil
      expect(detector.last_similarity).to be_within(0.001).of(1.0)
    end
  end
end
