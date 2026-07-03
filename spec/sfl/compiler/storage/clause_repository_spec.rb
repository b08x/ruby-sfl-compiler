# frozen_string_literal: true

require "spec_helper"
require "sequel"
Sequel.extension :pg_json unless Sequel.respond_to?(:pg_jsonb)

RSpec.describe SFL::Compiler::ClauseRepository do
  describe "#store" do
    let(:clauses_ds) { double("clauses dataset") }
    let(:ideational_ds) { double("ideational dataset") }
    let(:interpersonal_ds) { double("interpersonal dataset") }
    let(:db) do
      datasets = { clauses: clauses_ds, ideational_payloads: ideational_ds, interpersonal_payloads: interpersonal_ds }
      db = double("db")
      allow(db).to receive(:[]) { |table| datasets.fetch(table) }
      allow(db).to receive(:transaction).and_yield
      db
    end

    let(:token) do
      SFL::Compiler::Types::SyntacticToken.new(
        text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
        dep: "ROOT", head_index: -1, morphology: {}, index: 0
      )
    end
    let(:syntactic) do
      SFL::Compiler::Types::SyntacticClause.new(
        id: "syn-1", text: "It works.", tokens: [token], root_index: 0,
        sentence_index: 0, document_id: "doc-1"
      )
    end
    let(:ideational) do
      SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "clause-1", process_type: "relational", participants: [],
        circumstances: [], raw_transitivity: {}
      )
    end
    let(:interpersonal) do
      SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "clause-1", mood: "declarative", modality_weight: 0.5, tenor: 0.5,
        speaker_attitude: nil, reasoning: nil, annotation_source: "llm"
      )
    end
    let(:annotated) do
      SFL::Compiler::Types::AnnotatedClause.new(
        id: "clause-1", text: "It works.", syntactic:, ideational:, interpersonal:,
        document_id: "doc-1", compiled_at: Time.now
      )
    end

    before do
      allow(ideational_ds).to receive(:insert)
      allow(interpersonal_ds).to receive(:insert)
    end

    it "includes source_type in the clause insert when given" do
      expect(clauses_ds).to receive(:insert).with(hash_including(source_type: "chat_native"))

      described_class.new(db).store(annotated, source_type: "chat_native")
    end

    it "omits source_type from the insert when not given, deferring to the column's own default" do
      expect(clauses_ds).to receive(:insert).with(hash_excluding(:source_type))

      described_class.new(db).store(annotated)
    end
  end

  describe "#delete_by_document" do
    let(:clauses_ds) { double("clauses dataset") }
    let(:ideational_ds) { double("ideational dataset") }
    let(:interpersonal_ds) { double("interpersonal dataset") }
    let(:embeddings_ds) { double("embeddings dataset") }
    let(:db) do
      datasets = {
        clauses: clauses_ds, ideational_payloads: ideational_ds,
        interpersonal_payloads: interpersonal_ds, embeddings: embeddings_ds
      }
      db = double("db")
      allow(db).to receive(:[]) { |table| datasets.fetch(table) }
      allow(db).to receive(:transaction).and_yield
      db
    end

    it "deletes payloads, embeddings, then clauses for the document in one transaction" do
      filtered = double("filtered clauses")
      allow(clauses_ds).to receive(:where).with(document_id: "doc#intro").and_return(filtered)
      allow(filtered).to receive(:select_map).with(:external_id).and_return(%w[c1 c2])
      expect(filtered).to receive(:delete).and_return(2)

      [ideational_ds, interpersonal_ds, embeddings_ds].each do |ds|
        scoped = double("scoped")
        expect(ds).to receive(:where).with(clause_id: %w[c1 c2]).and_return(scoped)
        expect(scoped).to receive(:delete)
      end

      count = described_class.new(db).delete_by_document("doc#intro")
      expect(count).to eq(2)
    end

    it "returns 0 and deletes nothing further when no clauses match" do
      filtered = double("filtered clauses")
      allow(clauses_ds).to receive(:where).and_return(filtered)
      allow(filtered).to receive(:select_map).and_return([])

      expect(described_class.new(db).delete_by_document("missing")).to eq(0)
    end
  end
end
