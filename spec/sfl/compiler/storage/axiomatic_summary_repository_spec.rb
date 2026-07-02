# frozen_string_literal: true

require "spec_helper"
require "sequel"

RSpec.describe SFL::Compiler::AxiomaticSummaryRepository do
  let(:dataset) { double("dataset") }
  let(:inserted) { [] }
  let(:db) do
    d = double("db")
    allow(d).to receive(:[]).with(:axiomatic_summaries).and_return(dataset)
    d
  end

  before do
    allow(dataset).to receive(:insert) { |row| inserted << row; row }
    allow(dataset).to receive(:where).and_return(dataset)
    allow(dataset).to receive(:first).and_return(nil)
    allow(dataset).to receive(:order).and_return(dataset)
    allow(dataset).to receive(:all).and_return([])
    # pg_json Sequel extension is only available with a live DB connection.
    # Define a pass-through so unit tests work without a connection.
    Sequel.singleton_class.define_method(:pg_jsonb) { |v| v } unless Sequel.respond_to?(:pg_jsonb)
  end

  let(:repo) { described_class.new(db) }

  describe "#store" do
    let(:stored_row) { { id: "uuid-1", summary_text: "summary" } }

    before do
      allow(dataset).to receive(:first).and_return(stored_row)
    end

    it "inserts a row with the provided fields" do
      repo.store(
        workflow_id: "wf-1",
        source_clause_ids: %w[c1 c2],
        summary_text: "The discussion was formal and declarative.",
        core_claim: "Speaker A dominates material processes.",
        avg_tenor: 0.7,
        avg_modality: 0.6,
        clause_count: 2
      )

      expect(inserted.size).to eq(1)
      row = inserted.first
      expect(row[:workflow_id]).to eq("wf-1")
      expect(row[:summary_text]).to eq("The discussion was formal and declarative.")
      expect(row[:avg_tenor]).to eq(0.7)
      expect(row[:clause_count]).to eq(2)
    end

    it "generates a UUID id for each record" do
      repo.store(workflow_id: "wf-1", source_clause_ids: [], summary_text: "x")
      repo.store(workflow_id: "wf-1", source_clause_ids: [], summary_text: "y")

      ids = inserted.map { |r| r[:id] }
      expect(ids.uniq.size).to eq(2)
      expect(ids).to all(match(/\A[0-9a-f-]{36}\z/))
    end

    it "returns the stored record via find after insert" do
      result = repo.store(workflow_id: "wf-2", source_clause_ids: [], summary_text: "z")
      expect(result).to eq(stored_row)
    end

    it "applies default values for optional fields" do
      repo.store(workflow_id: "wf-1", source_clause_ids: [], summary_text: "minimal")

      row = inserted.first
      expect(row[:avg_tenor]).to eq(0.5)
      expect(row[:avg_modality]).to eq(0.5)
      expect(row[:clause_count]).to eq(0)
    end
  end

  describe "#for_workflow" do
    it "queries by workflow_id ordered by created_at" do
      expect(dataset).to receive(:where).with(workflow_id: "wf-1").and_return(dataset)
      expect(dataset).to receive(:order).with(:created_at).and_return(dataset)
      expect(dataset).to receive(:all).and_return([])

      repo.for_workflow("wf-1")
    end
  end

  describe "#latest_for_workflow" do
    it "queries descending by created_at and returns first" do
      expect(dataset).to receive(:where).with(workflow_id: "wf-X").and_return(dataset)
      expect(dataset).to receive(:order).with(Sequel.desc(:created_at)).and_return(dataset)
      expect(dataset).to receive(:first).and_return(nil)

      repo.latest_for_workflow("wf-X")
    end
  end
end
