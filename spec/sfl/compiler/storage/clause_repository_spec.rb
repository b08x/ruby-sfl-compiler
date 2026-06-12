# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::ClauseRepository do
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
