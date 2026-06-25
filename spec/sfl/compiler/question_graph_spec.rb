# frozen_string_literal: true

# rubocop:disable Naming/AsciiIdentifiers -- exercises #gödel_number, named
# with the umlaut per the QuestionGraph card/track throughout.

require "spec_helper"

RSpec.describe SFL::Compiler::QuestionGraph do
  describe "axiomatic questions" do
    it "assigns the first sequential primes to questions with no dependencies" do
      graph = described_class.new([
        { id: :q1, text: "a", dependencies: [] },
        { id: :q2, text: "b", dependencies: [] },
        { id: :q3, text: "c", dependencies: [] },
      ])

      expect(graph.values.values_at(:q1, :q2, :q3)).to eq([2, 3, 5])
    end
  end

  describe "derived questions" do
    it "multiplies a fresh seed prime by the product of dependency values" do
      graph = described_class.new([
        { id: :q1, text: "a", dependencies: [] },
        { id: :q2, text: "b", dependencies: [] },
        { id: :q3, text: "derived", dependencies: %i[q1 q2] },
      ])

      # q1 => 2, q2 => 3, q3's seed is the next prime after 2,3 => 5,
      # value = 5 * (2 * 3) = 30
      expect(graph.values[:q1]).to eq(2)
      expect(graph.values[:q2]).to eq(3)
      expect(graph.values[:q3]).to eq(30)
    end

    it "never collides with its single dependency's own value" do
      graph = described_class.new([
        { id: :q1, text: "a", dependencies: [] },
        { id: :q4, text: "derived from one", dependencies: [:q1] },
      ])

      expect(graph.values[:q4]).not_to eq(graph.values[:q1])
      expect(graph.values[:q4]).to be > graph.values[:q1]
    end

    it "resolves a deeply nested dependency chain regardless of input order" do
      graph = described_class.new([
        { id: :q, text: "outer", dependencies: [:q_prime] },
        { id: :q_prime, text: "middle", dependencies: [:q_double_prime] },
        { id: :q_double_prime, text: "innermost", dependencies: [] },
      ])

      expect(graph.values[:q_double_prime]).to eq(2)
      expect(graph.values[:q_prime]).to eq(3 * 2)
      expect(graph.values[:q]).to eq(5 * (3 * 2))
    end
  end

  describe "#gödel_number" do
    it "is the product of every question's assigned value" do
      graph = described_class.new([
        { id: :q1, text: "a", dependencies: [] },
        { id: :q4, text: "derived", dependencies: [:q1] },
      ])

      expect(graph.gödel_number).to eq(graph.values[:q1] * graph.values[:q4])
    end

    it "produces a composite integer for the acceptance example" do
      graph = described_class.new([
        { id: :q1, text: "...", dependencies: [] },
        { id: :q4, text: "...", dependencies: [:q1] },
      ])

      expect(graph.gödel_number).to be_a(Integer)
      expect(Prime.prime?(graph.gödel_number)).to be(false)
    end
  end

  describe "#factor" do
    it "returns a prime => exponent hash" do
      graph = described_class.new([{ id: :q1, text: "a", dependencies: [] }])

      expect(graph.factor(12)).to eq({ 2 => 2, 3 => 1 })
    end

    it "defaults to factoring this graph's own gödel_number" do
      graph = described_class.new([{ id: :q1, text: "a", dependencies: [] }])

      expect(graph.factor).to eq({ 2 => 1 })
    end
  end

  describe "#decode and #consistent?" do
    it "recovers the original question id set for a 5-question graph" do
      graph = described_class.new([
        { id: :q1, text: "a", dependencies: [] },
        { id: :q2, text: "b", dependencies: [] },
        { id: :q3, text: "c", dependencies: [] },
        { id: :q4, text: "derived from q1", dependencies: [:q1] },
        { id: :q5, text: "derived from q2 and q3", dependencies: %i[q2 q3] },
      ])

      expect(graph.decode.sort).to eq(%i[q1 q2 q3 q4 q5].sort)
      expect(graph).to be_consistent
    end

    it "handles a single-question graph (gödel number is the prime itself)" do
      graph = described_class.new([{ id: :q1, text: "only one", dependencies: [] }])

      expect(graph.gödel_number).to eq(2)
      expect(graph.decode).to eq([:q1])
      expect(graph).to be_consistent
    end

    it "handles a deeply nested dependency chain" do
      graph = described_class.new([
        { id: :q, text: "outer", dependencies: [:q_prime] },
        { id: :q_prime, text: "middle", dependencies: [:q_double_prime] },
        { id: :q_double_prime, text: "innermost", dependencies: [] },
      ])

      expect(graph.decode.sort).to eq(%i[q q_prime q_double_prime].sort)
      expect(graph).to be_consistent
    end
  end

  describe "cyclic or unresolved dependencies" do
    it "raises QuestionGraphError for a cycle" do
      expect do
        described_class.new([
          { id: :a, text: "a", dependencies: [:b] },
          { id: :b, text: "b", dependencies: [:a] },
        ])
      end.to raise_error(SFL::Compiler::QuestionGraphError, /[Cc]yclic/)
    end

    it "raises QuestionGraphError for a dependency id that doesn't exist" do
      expect do
        described_class.new([
          { id: :a, text: "a", dependencies: [:missing] },
        ])
      end.to raise_error(SFL::Compiler::QuestionGraphError)
    end
  end
end
# rubocop:enable Naming/AsciiIdentifiers
