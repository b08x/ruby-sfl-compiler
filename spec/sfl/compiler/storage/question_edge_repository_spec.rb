# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::QuestionEdgeRepository do
  def build_chain(length)
    questions = (1..length).map { |i|
      {
        id: "q#{i}",
        text: "Question #{i}",
        dependencies: i == 1 ? [] : ["q#{i - 1}"]
      }
    }
    SFL::Compiler::QuestionGraph.new(questions)
  end

  def stub_db(dataset:, rows: [])
    allow(dataset).to receive(:where).and_return(dataset)
    allow(dataset).to receive(:delete)
    allow(dataset).to receive(:all).and_return(rows)
    inserted = []
    allow(dataset).to receive(:insert) { |row| inserted << row }

    db = double("db")
    allow(db).to receive(:[]).with(:question_edges).and_return(dataset)
    allow(db).to receive(:transaction).and_yield
    [db, inserted]
  end

  describe "#store" do
    it "inserts one edge per dependency with correct parent_id, child_id, depth" do
      graph = build_chain(3)  # q1→q2→q3; 2 edges
      dataset = double("dataset")
      db, inserted = stub_db(dataset:)

      described_class.new(db).store(graph)

      pairs = inserted.map { |r| [r[:parent_id], r[:child_id]] }
      expect(pairs).to match_array([["q1", "q2"], ["q2", "q3"]])
      expect(inserted.find { |r| r[:child_id] == "q2" }[:depth]).to eq(1)
      expect(inserted.find { |r| r[:child_id] == "q3" }[:depth]).to eq(2)
    end

    it "inserts nothing for a single-node graph (no edges)" do
      graph = SFL::Compiler::QuestionGraph.new([{ id: "q1", text: "Root" }])
      dataset = double("dataset")
      db, inserted = stub_db(dataset:)

      described_class.new(db).store(graph)

      expect(inserted).to be_empty
    end
  end

  describe "#reconstruct" do
    it "rebuilds a 10-node deep chain with correct depth and topology" do
      questions = (1..10).map { |i| { id: "q#{i}", text: "Question #{i}" } }
      rows = (1..9).map { |i| { parent_id: "q#{i}", child_id: "q#{i + 1}", depth: i } }

      dataset = double("dataset")
      db, _inserted = stub_db(dataset:, rows:)

      graph = described_class.new(db).reconstruct(questions)

      expect(graph.depth("q10")).to eq(9)
      expect(graph.topological_order.first).to eq("q1")
      expect(graph.topological_order.last).to eq("q10")
      expect(graph.roots).to eq(["q1"])
      expect(graph.leaves).to eq(["q10"])
    end

    it "returns an isolated node graph when there are no edges" do
      questions = [{ id: "q1", text: "Root" }]
      dataset = double("dataset")
      db, _inserted = stub_db(dataset:, rows: [])

      graph = described_class.new(db).reconstruct(questions)

      expect(graph.roots).to eq(["q1"])
      expect(graph.depth("q1")).to eq(0)
    end

    it "handles a diamond DAG (q1→q2, q1→q3, q2→q4, q3→q4)" do
      questions = %w[q1 q2 q3 q4].map { |id| { id:, text: id } }
      rows = [
        { parent_id: "q1", child_id: "q2", depth: 1 },
        { parent_id: "q1", child_id: "q3", depth: 1 },
        { parent_id: "q2", child_id: "q4", depth: 2 },
        { parent_id: "q3", child_id: "q4", depth: 2 }
      ]
      dataset = double("dataset")
      db, _inserted = stub_db(dataset:, rows:)

      graph = described_class.new(db).reconstruct(questions)

      expect(graph.roots).to eq(["q1"])
      expect(graph.leaves).to eq(["q4"])
      expect(graph.parents("q4")).to match_array(%w[q2 q3])
    end
  end

  describe "#reachable" do
    it "returns descendant ids from the CTE result" do
      rows = [{ child_id: "q2" }, { child_id: "q3" }]
      dataset = double("cte_dataset")
      allow(dataset).to receive(:all).and_return(rows)

      db = double("db")
      allow(db).to receive(:fetch).and_return(dataset)

      result = described_class.new(db).reachable("q1")

      expect(result).to contain_exactly("q2", "q3")
    end
  end
end
