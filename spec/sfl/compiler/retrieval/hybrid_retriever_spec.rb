# frozen_string_literal: true

require "spec_helper"
require "sequel"

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

  # A minimal stand-in for a Sequel::Postgres::Dataset. Real datasets are
  # Enumerable (via #each), so chained query methods return something that
  # responds to #to_a, #each, #map, etc. — but NOT #map_with_index. Any
  # double here that responded to map_with_index would mask the bug this
  # class exists to catch.
  class FakeDataset
    include Enumerable

    def initialize(rows)
      @rows = rows
    end

    def join(*) = self
    def order(*) = self
    def limit(*) = self
    def where(*) = self
    def select(*) = self

    def each(&block)
      @rows.each(&block)
    end
  end

  describe "#retrieve" do
    let(:db) { double("db") }
    let(:embedder) { double("embedder", embed: [0.1, 0.2, 0.3]) }

    let(:semantic_rows) do
      [
        { clause_id: "clause-1", text: "semantic one", document_id: "doc#a", similarity_score: 0.9 },
        { clause_id: "clause-2", text: "semantic two", document_id: "doc#b", similarity_score: 0.5 }
      ]
    end

    let(:keyword_rows) do
      [
        { clause_id: "clause-3", text: "keyword one", document_id: "doc#c" }
      ]
    end

    before do
      embeddings_table = FakeDataset.new(semantic_rows)
      clauses_table = double("clauses_table")

      allow(db).to receive(:[]).with(:embeddings).and_return(embeddings_table)
      allow(db).to receive(:[]).with(:clauses).and_return(clauses_table)
      allow(clauses_table).to receive(:where).and_return(FakeDataset.new(keyword_rows))
    end

    it "ranks semantic search results starting at 1" do
      retriever = described_class.new(db: db, embedder: embedder)

      results = retriever.retrieve("a query", limit: 10)

      semantic = results.select { |r| r[:semantic_rank] }
      expect(semantic.map { |r| r[:semantic_rank] }).to eq([1, 2])
    end

    it "ranks keyword search results starting at 1" do
      retriever = described_class.new(db: db, embedder: embedder)

      results = retriever.retrieve("a query", limit: 10)

      keyword = results.select { |r| r[:keyword_rank] }
      expect(keyword.map { |r| r[:keyword_rank] }).to eq([1])
    end

    it "returns rows merged from both search paths" do
      retriever = described_class.new(db: db, embedder: embedder)

      results = retriever.retrieve("a query", limit: 10)
      clause_ids = results.map { |r| r[:clause_id] }

      expect(clause_ids).to contain_exactly("clause-1", "clause-2", "clause-3")
    end
  end

  describe "#retrieve with a source_type filter" do
    let(:db) { double("db") }
    let(:embedder) { double("embedder", embed: [0.1, 0.2, 0.3]) }

    let(:semantic_rows) do
      [{ clause_id: "clause-1", text: "chat clause", document_id: "turn-1", similarity_score: 0.9 }]
    end
    let(:keyword_rows) do
      [{ clause_id: "clause-2", text: "vault clause", document_id: "note#a" }]
    end
    let(:interpersonal_map) do
      { "clause-1" => { mood: "declarative", modality_weight: 0.5, tenor: 0.5 },
        "clause-2" => { mood: "declarative", modality_weight: 0.5, tenor: 0.5 } }
    end
    let(:source_type_map) { { "clause-1" => "chat_native", "clause-2" => "vault_markdown" } }

    before do
      embeddings_table = FakeDataset.new(semantic_rows)
      clauses_table = double("clauses_table")
      interpersonal_table = double("interpersonal_table")
      ideational_table = double("ideational_table")

      allow(db).to receive(:[]).with(:embeddings).and_return(embeddings_table)
      allow(db).to receive(:[]).with(:clauses).and_return(clauses_table)
      allow(db).to receive(:[]).with(:interpersonal_payloads).and_return(interpersonal_table)
      allow(db).to receive(:[]).with(:ideational_payloads).and_return(ideational_table)
      allow(ideational_table).to receive(:where).and_return(double("scoped", as_hash: {}))

      # keyword_search filters with a Sequel.lit(...) positional arg;
      # apply_filters' source_type lookup filters with a keyword hash —
      # discriminate on shape rather than exact value.
      allow(clauses_table).to receive(:where) do |arg|
        arg.is_a?(Hash) ? double("scoped", as_hash: source_type_map) : FakeDataset.new(keyword_rows)
      end
      allow(interpersonal_table).to receive(:where).and_return(double("scoped", as_hash: interpersonal_map))
    end

    it "keeps only clauses matching the source_type filter" do
      retriever = described_class.new(db: db, embedder: embedder)

      results = retriever.retrieve("a query", limit: 10, filters: { source_type: "vault_markdown" })

      expect(results.map { |r| r[:clause_id] }).to eq(["clause-2"])
    end

    it "excludes nothing when the filter is absent" do
      retriever = described_class.new(db: db, embedder: embedder)

      results = retriever.retrieve("a query", limit: 10)

      expect(results.map { |r| r[:clause_id] }).to contain_exactly("clause-1", "clause-2")
    end
  end
end
