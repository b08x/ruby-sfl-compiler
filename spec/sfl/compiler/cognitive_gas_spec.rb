# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::CognitiveGas do
  subject(:gas) { described_class.new(budget: 100) }

  describe "initialization" do
    it "reads COGNITIVE_GAS_BUDGET from env when no kwarg is given" do
      allow(ENV).to receive(:fetch).with("COGNITIVE_GAS_BUDGET", described_class::DEFAULT_BUDGET)
        .and_return(500)
      g = described_class.new
      expect(g.budget).to eq(500)
    end

    it "defaults to DEFAULT_BUDGET when env is unset" do
      g = described_class.new
      expect(g.budget).to eq(described_class::DEFAULT_BUDGET)
    end
  end

  describe "#call" do
    it "executes the block and returns its value when budget remains" do
      expect(gas.call { 42 }).to eq(42)
    end

    it "raises CircuitBreaker::CircuitBrokenException when budget is exhausted" do
      gas.charge(100)
      expect { gas.call { :anything } }.to raise_error(CircuitBreaker::CircuitBrokenException, /budget exhausted/)
    end

    it "raises immediately if budget starts at zero" do
      empty = described_class.new(budget: 0)
      expect { empty.call { } }.to raise_error(CircuitBreaker::CircuitBrokenException)
    end
  end

  describe "#charge_batch" do
    def clause(token_count: 5)
      tokens = Array.new(token_count) do |i|
        double("Token",
          text: "word#{i}", lemma: "word", pos: "NOUN", tag: "NN",
          dep: "nsubj", head_index: 0, morphology: {}, index: i)
      end
      double("SyntacticClause", tokens: tokens)
    end

    def ideational(process_type:, participants: [])
      double("IdeationalPayload",
        process_type: process_type,
        participants: participants)
    end

    it "increments spent by the batch cost" do
      batch = [
        { clause: clause(token_count: 5), ideational: ideational(process_type: "material") },
        { clause: clause(token_count: 3), ideational: ideational(process_type: "relational") }
      ]
      # material: 3 + 5 tokens + 0 participants = 8
      # relational: 1 + 3 tokens + 0 participants = 4
      expect(gas.charge_batch(batch)).to eq(12)
      expect(gas.spent).to eq(12)
    end

    it "caps token cost at TOKEN_CAP (20)" do
      batch = [{ clause: clause(token_count: 50), ideational: ideational(process_type: "existential") }]
      # existential: 1 + 20 (capped) + 0 = 21
      cost = gas.charge_batch(batch)
      expect(cost).to eq(21)
    end

    it "adds participant cost to the total" do
      participants = Array.new(3) { double("Participant") }
      batch = [{ clause: clause(token_count: 4), ideational: ideational(process_type: "mental", participants: participants) }]
      # mental: 3 + 4 + 3 participants = 10
      expect(gas.charge_batch(batch)).to eq(10)
    end

    it "accepts [clause, ideational] pair format as well as Hash format" do
      c = clause(token_count: 5)
      i = ideational(process_type: "verbal")
      # verbal: 2 + 5 + 0 = 7
      expect(gas.charge_batch([[c, i]])).to eq(7)
    end

    it "returns 0 and charges nothing for an empty batch" do
      expect(gas.charge_batch([])).to eq(0)
      expect(gas.spent).to eq(0)
    end
  end

  describe "#charge" do
    it "adds the given amount to spent" do
      gas.charge(30)
      gas.charge(25)
      expect(gas.spent).to eq(55)
    end
  end

  describe "#reset!" do
    it "clears spent to zero without changing budget" do
      gas.charge(80)
      gas.reset!
      expect(gas.spent).to eq(0)
      expect(gas.budget).to eq(100)
    end

    it "allows further calls after reset" do
      gas.charge(100)
      expect { gas.call { } }.to raise_error(CircuitBreaker::CircuitBrokenException)
      gas.reset!
      expect(gas.call { :ok }).to eq(:ok)
    end
  end

  describe "#remaining and #exhausted?" do
    it "tracks remaining budget correctly" do
      gas.charge(40)
      expect(gas.remaining).to eq(60)
      expect(gas.exhausted?).to be false
    end

    it "reports exhausted when spent equals budget" do
      gas.charge(100)
      expect(gas.exhausted?).to be true
      expect(gas.remaining).to eq(0)
    end
  end
end
