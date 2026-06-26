# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::QuestionGraph do
  let(:three_roots) do
    described_class.new([
      { id: :q1, text: "a", dependencies: [] },
      { id: :q2, text: "b", dependencies: [] },
      { id: :q3, text: "c", dependencies: [] },
    ])
  end

  # q1 ─┐
  # q2 ─┴─► q3 ─► q4
  let(:diamond) do
    described_class.new([
      { id: :q1, text: "a", dependencies: [] },
      { id: :q2, text: "b", dependencies: [] },
      { id: :q3, text: "derived from q1 and q2", dependencies: %i[q1 q2] },
      { id: :q4, text: "derived from q3", dependencies: [:q3] },
    ])
  end

  describe "#nodes / #questions" do
    it "stores all questions keyed by id" do
      expect(three_roots.nodes.keys).to match_array(%i[q1 q2 q3])
    end

    it "aliases as #questions" do
      expect(three_roots.questions).to be(three_roots.nodes)
    end
  end

  describe "#roots" do
    it "returns questions with no dependencies" do
      expect(three_roots.roots).to match_array(%i[q1 q2 q3])
    end

    it "excludes derived questions" do
      expect(diamond.roots).to match_array(%i[q1 q2])
    end
  end

  describe "#leaves" do
    it "returns questions that nothing else depends on" do
      expect(diamond.leaves).to eq([:q4])
    end

    it "treats a standalone graph as all roots and all leaves" do
      expect(three_roots.leaves).to match_array(%i[q1 q2 q3])
    end
  end

  describe "#parents" do
    it "returns direct dependencies of a question" do
      expect(diamond.parents(:q3)).to match_array(%i[q1 q2])
    end

    it "returns empty for a root question" do
      expect(diamond.parents(:q1)).to eq([])
    end
  end

  describe "#children" do
    it "returns questions that directly depend on the given id" do
      expect(diamond.children(:q3)).to eq([:q4])
    end

    it "returns empty for a leaf" do
      expect(diamond.children(:q4)).to eq([])
    end
  end

  describe "#ancestors" do
    it "returns all upstream questions transitively" do
      expect(diamond.ancestors(:q4)).to match_array(%i[q3 q1 q2])
    end

    it "returns empty for a root" do
      expect(diamond.ancestors(:q1)).to eq([])
    end
  end

  describe "#descendants" do
    it "returns all downstream questions transitively" do
      expect(diamond.descendants(:q1)).to match_array(%i[q3 q4])
    end

    it "returns empty for a leaf" do
      expect(diamond.descendants(:q4)).to eq([])
    end
  end

  describe "#reachable?" do
    it "is true when a path exists between two questions" do
      expect(diamond.reachable?(from: :q1, to: :q4)).to be(true)
    end

    it "is false when no path exists" do
      expect(diamond.reachable?(from: :q4, to: :q1)).to be(false)
    end
  end

  describe "#depth" do
    it "is 0 for root questions" do
      expect(diamond.depth(:q1)).to eq(0)
    end

    it "is 1 for a question one hop from a root" do
      expect(diamond.depth(:q3)).to eq(1)
    end

    it "is 2 for a question two hops from a root" do
      expect(diamond.depth(:q4)).to eq(2)
    end
  end

  describe "#topological_order" do
    it "places all dependencies before their dependents" do
      order = diamond.topological_order
      expect(order.index(:q1)).to be < order.index(:q3)
      expect(order.index(:q2)).to be < order.index(:q3)
      expect(order.index(:q3)).to be < order.index(:q4)
    end

    it "resolves regardless of input order" do
      graph = described_class.new([
        { id: :q, text: "outer", dependencies: [:q_prime] },
        { id: :q_prime, text: "middle", dependencies: [:q_double_prime] },
        { id: :q_double_prime, text: "innermost", dependencies: [] },
      ])

      order = graph.topological_order
      expect(order.index(:q_double_prime)).to be < order.index(:q_prime)
      expect(order.index(:q_prime)).to be < order.index(:q)
    end
  end

  describe "error cases" do
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
      end.to raise_error(SFL::Compiler::QuestionGraphError, /missing/)
    end
  end
end
