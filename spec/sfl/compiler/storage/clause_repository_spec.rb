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

  describe "#find_pass_one_output" do
    let(:clauses_ds) { double("clauses dataset") }
    let(:ideational_ds) { double("ideational dataset") }
    let(:db) do
      datasets = { clauses: clauses_ds, ideational_payloads: ideational_ds }
      double("db", :[] => nil).tap { |d| allow(d).to receive(:[]) { |t| datasets.fetch(t) } }
    end

    # jsonb columns round-trip with STRING keys (verified live against a
    # real Postgres DB, not just asserted here) — unlike the symbol-keyed
    # hashes #store's own callers build from Dry::Struct#to_h.
    let(:stored_clause_row) do
      {
        external_id: "clause-1", text: "It works.", document_id: "doc-1", sentence_index: 0,
        tokens: [
          { "text" => "It", "lemma" => "it", "pos" => "PRON", "tag" => "PRP", "dep" => "nsubj",
            "head_index" => 1, "morphology" => {}, "index" => 0 },
          { "text" => "works", "lemma" => "work", "pos" => "VERB", "tag" => "VBZ", "dep" => "ROOT",
            "head_index" => -1, "morphology" => {}, "index" => 1 },
        ],
      }
    end
    let(:stored_ideational_row) do
      {
        process_type: "material",
        participants: [{ "role" => "Actor", "text" => "It" }],
        circumstances: [],
        raw_transitivity: {},
      }
    end

    it "returns nil when the clause doesn't exist" do
      allow(clauses_ds).to receive(:where).with(external_id: "missing").and_return(clauses_ds)
      allow(clauses_ds).to receive(:first).and_return(nil)

      expect(described_class.new(db).find_pass_one_output("missing")).to be_nil
    end

    it "returns nil when the clause exists but has no ideational payload" do
      allow(clauses_ds).to receive(:where).with(external_id: "clause-1").and_return(clauses_ds)
      allow(clauses_ds).to receive(:first).and_return(stored_clause_row)
      allow(ideational_ds).to receive(:where).with(clause_id: "clause-1").and_return(ideational_ds)
      allow(ideational_ds).to receive(:first).and_return(nil)

      expect(described_class.new(db).find_pass_one_output("clause-1")).to be_nil
    end

    it "reconstructs typed SyntacticClause/IdeationalPayload structs, deriving root_index from dep == ROOT" do
      allow(clauses_ds).to receive(:where).with(external_id: "clause-1").and_return(clauses_ds)
      allow(clauses_ds).to receive(:first).and_return(stored_clause_row)
      allow(ideational_ds).to receive(:where).with(clause_id: "clause-1").and_return(ideational_ds)
      allow(ideational_ds).to receive(:first).and_return(stored_ideational_row)

      result = described_class.new(db).find_pass_one_output("clause-1")

      expect(result[:syntactic]).to be_a(SFL::Compiler::Types::SyntacticClause)
      expect(result[:syntactic].root_index).to eq(1)
      expect(result[:syntactic].tokens.map(&:text)).to eq(%w[It works])
      expect(result[:ideational]).to be_a(SFL::Compiler::Types::IdeationalPayload)
      expect(result[:ideational].participants.first.text).to eq("It")
    end
  end

  describe "#update_interpersonal" do
    it "updates the existing interpersonal_payloads row by clause_id and returns the row count" do
      interpersonal = SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "clause-1", mood: "interrogative", modality_weight: 0.9, tenor: 0.8,
        speaker_attitude: "curious", reasoning: "re-annotated", annotation_source: "llm"
      )
      scoped = double("scoped interpersonal_payloads")
      ds = double("interpersonal_payloads dataset")
      allow(ds).to receive(:where).with(clause_id: "clause-1").and_return(scoped)
      allow(scoped).to receive(:update).with(
        mood: "interrogative", modality_weight: 0.9, tenor: 0.8,
        speaker_attitude: "curious", reasoning: "re-annotated", annotation_source: "llm"
      ).and_return(1)
      db = double("db", :[] => ds)

      expect(described_class.new(db).update_interpersonal("clause-1", interpersonal)).to eq(1)
    end
  end

  describe "#record_review" do
    let(:reviews_ds) { double("annotation_reviews dataset") }
    let(:db) { double("db", :[] => reviews_ds) }

    it "inserts a review row and returns the built Types::AnnotationReview" do
      expect(reviews_ds).to receive(:insert).with(
        hash_including(
          clause_id: "clause-1", decision: "accepted",
          original_annotation_source: "fallback", reviewer: "bob"
        )
      )

      review = described_class.new(db).record_review(
        clause_id: "clause-1", decision: "accepted",
        original_annotation_source: "fallback", reviewer: "bob"
      )

      expect(review).to be_a(SFL::Compiler::Types::AnnotationReview)
      expect(review.clause_id).to eq("clause-1")
    end

    it "defaults reviewer and notes to nil" do
      expect(reviews_ds).to receive(:insert).with(hash_including(reviewer: nil, notes: nil))

      described_class.new(db).record_review(
        clause_id: "clause-1", decision: "rejected", original_annotation_source: "stub"
      )
    end
  end

  describe "#reviews_for" do
    it "queries annotation_reviews by clause_id ordered by reviewed_at" do
      ds = double("dataset")
      expect(ds).to receive(:where).with(clause_id: "clause-1").and_return(ds)
      expect(ds).to receive(:order).with(:reviewed_at).and_return(ds)
      expect(ds).to receive(:all).and_return([{ id: "r1" }])
      db = double("db", :[] => ds)

      expect(described_class.new(db).reviews_for("clause-1")).to eq([{ id: "r1" }])
    end
  end

  # find_all's actual SQL correctness (the double-join column-ambiguity
  # risk called out in its docstring) was verified live against a real
  # Postgres DB before this method was written, not just asserted here —
  # this spec covers this method's own logic (which filter keys get
  # applied, pagination shape) with a chainable fake scope, not Sequel's
  # join semantics.
  describe "#find_all" do
    # Records every #where call it receives; every other chain method
    # (join/order/limit/select) returns self so the whole chain is
    # inspectable at the end via #where_calls.
    class FakeScope
      include Enumerable

      attr_reader :where_calls

      def initialize(rows: [], total: nil)
        @rows = rows
        @total = total || rows.size
        @where_calls = []
      end

      def join(*) = self
      def order(*) = self
      def limit(*) = self
      def select(*) = self
      def where(condition) = tap { @where_calls << condition }
      def count = @total
      def all = @rows
      def each(&) = @rows.each(&)
    end

    it "applies only the filter keys present in FIND_ALL_FILTERS, ignoring unknown/nil ones" do
      scope = FakeScope.new
      db = double("db", :[] => scope)

      described_class.new(db).find_all(
        filters: { mood: "declarative", source_type: nil, bogus_key: "x" }
      )

      expect(scope.where_calls.size).to eq(1)
      expect(scope.where_calls.first).to eq({ Sequel[:interpersonal_payloads][:mood] => "declarative" })
    end

    it "builds range conditions (not equality hashes) for min/max filters" do
      scope = FakeScope.new
      db = double("db", :[] => scope)

      described_class.new(db).find_all(filters: { min_tenor: 0.6 })

      expect(scope.where_calls.first).to be_a(Sequel::SQL::BooleanExpression)
    end

    it "returns clauses and total from the scope's #all and #count" do
      rows = [{ id: "c1" }, { id: "c2" }]
      scope = FakeScope.new(rows:, total: 42)
      db = double("db", :[] => scope)

      result = described_class.new(db).find_all

      expect(result).to eq(clauses: rows, total: 42)
    end

    it "runs with no filters at all (browse-everything case)" do
      scope = FakeScope.new
      db = double("db", :[] => scope)

      described_class.new(db).find_all

      expect(scope.where_calls).to be_empty
    end
  end
end
