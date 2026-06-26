# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::CrossDocumentGraph do
  def doc_graph(modality_id: :modality, extra: [])
    SFL::Compiler::QuestionGraph.new([
      { id: modality_id, text: "What is the average modality?", dependencies: [] },
      { id: :data_quality, text: "Are there fallback annotations?", dependencies: [] },
      *extra,
    ])
  end

  describe ".aggregate" do
    it "reveals a derived question that wasn't in either individual document's graph (the acceptance example)" do
      formal_doc = doc_graph
      informal_doc = doc_graph

      result = described_class.aggregate([formal_doc, informal_doc])

      new_ids = result.graph.questions.keys - formal_doc.questions.keys - informal_doc.questions.keys
      expect(new_ids).to include(:cross_doc_modality_consistency)
      expect(result.graph.questions[:cross_doc_modality_consistency][:text])
        .to eq("Does the modality finding hold across documents?")
    end

    it "namespaces per-document question ids so two docs' own :modality axioms don't collide" do
      result = described_class.aggregate([doc_graph, doc_graph])

      expect(result.graph.questions).to include(:"doc0.modality", :"doc1.modality")
    end

    it "the cross-doc question depends on each document's own namespaced question" do
      result = described_class.aggregate([doc_graph, doc_graph])

      deps = result.graph.questions[:cross_doc_modality_consistency][:dependencies]
      expect(deps).to contain_exactly(:"doc0.modality", :"doc1.modality")
    end

    it "produces no deferred questions for a single document" do
      result = described_class.aggregate([doc_graph])

      expect(result.deferred_questions).to eq([])
    end

    it "does not cross a question only one document asks" do
      a = doc_graph(extra: [{ id: :unique_to_a, text: "only in A", dependencies: [] }])
      b = doc_graph

      result = described_class.aggregate([a, b])

      ids = result.deferred_questions.map { |q| q[:id] }
      expect(ids).not_to include(:cross_doc_unique_to_a_consistency)
    end

    it "produces a reconciliation-needed question for 3 documents with divergent findings" do
      graphs = Array.new(3) { doc_graph }
      findings = [{ modality: 0.85 }, { modality: 0.30 }, { modality: 0.78 }]

      result = described_class.aggregate(graphs, findings:)

      ids = result.deferred_questions.map { |q| q[:id] }
      expect(ids).to include(:reconciliation_needed_modality)
    end

    it "does not produce a reconciliation question when 3 documents' findings agree" do
      graphs = Array.new(3) { doc_graph }
      findings = [{ modality: 0.80 }, { modality: 0.82 }, { modality: 0.79 }]

      result = described_class.aggregate(graphs, findings:)

      ids = result.deferred_questions.map { |q| q[:id] }
      expect(ids).not_to include(:reconciliation_needed_modality)
    end

    it "does not produce a reconciliation question with only 2 documents, even with divergent findings" do
      graphs = Array.new(2) { doc_graph }
      findings = [{ modality: 0.9 }, { modality: 0.1 }]

      result = described_class.aggregate(graphs, findings:)

      ids = result.deferred_questions.map { |q| q[:id] }
      expect(ids).not_to include(:reconciliation_needed_modality)
      expect(ids).to include(:cross_doc_modality_consistency)
    end

    it "skips reconciliation when findings are missing for some documents" do
      graphs = Array.new(3) { doc_graph }
      findings = [{ modality: 0.9 }, {}, { modality: 0.1 }]

      result = described_class.aggregate(graphs, findings:)

      ids = result.deferred_questions.map { |q| q[:id] }
      expect(ids).not_to include(:reconciliation_needed_modality)
    end

    it "merges into a QuestionGraph with roots and leaves" do
      result = described_class.aggregate([doc_graph, doc_graph])

      expect(result.graph.roots).not_to be_empty
      expect(result.graph.leaves).not_to be_empty
      expect(result.graph.topological_order.size).to eq(result.graph.nodes.size)
    end
  end
end
