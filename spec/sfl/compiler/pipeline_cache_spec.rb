# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe SFL::Compiler::PipelineCache do
  subject(:cache) { described_class.new(cache_dir: cache_dir) }

  let(:cache_dir) { Dir.mktmpdir("sfl-cache-test") }
  let(:document_id) { "test-doc-1" }

  after { FileUtils.rm_rf(cache_dir) }

  # Helper to build a minimal SyntacticClause
  def build_clause(text: "The cat sat.", id: "clause-1")
    SFL::Compiler::Types::SyntacticClause.new(
      id: id,
      text: text,
      tokens: [
        SFL::Compiler::Types::SyntacticToken.new(
          text: "cat", lemma: "cat", pos: "NOUN", tag: "NN",
          dep: "nsubj", head_index: 2, morphology: {}, index: 1
        )
      ],
      root_index: 2,
      sentence_index: 0,
      document_id: document_id
    )
  end

  # Helper to build a minimal AnnotatedClause
  def build_annotated(text: "The cat sat.", id: "clause-1")
    clause = build_clause(text: text, id: id)
    SFL::Compiler::Types::AnnotatedClause.new(
      id: id,
      text: text,
      syntactic: clause,
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: id,
        process_type: "material",
        participants: [],
        circumstances: [],
        raw_transitivity: { root: "sat", actor: "cat" }
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: id,
        mood: "declarative",
        modality_weight: 0.5,
        tenor: 0.5,
        speaker_attitude: nil,
        reasoning: "test",
        annotation_source: "llm"
      ),
      document_id: document_id,
      compiled_at: Time.now
    )
  end

  describe "#store and #fetch" do
    it "stores and retrieves an annotated clause" do
      clause = build_clause
      annotated = build_annotated

      cache.store(document_id, clause, annotated)
      result = cache.fetch(document_id, clause)

      expect(result).not_to be_nil
      expect(result.id).to eq(annotated.id)
      expect(result.text).to eq(annotated.text)
      expect(result.interpersonal.mood).to eq("declarative")
      expect(result.interpersonal.tenor).to eq(0.5)
    end

    it "returns nil for uncached clauses" do
      clause = build_clause
      result = cache.fetch(document_id, clause)
      expect(result).to be_nil
    end

    it "creates deterministic cache paths" do
      clause1 = build_clause(text: "Hello world")
      clause2 = build_clause(text: "Hello world")

      cache.store(document_id, clause1, build_annotated(text: "Hello world"))
      result = cache.fetch(document_id, clause2)

      expect(result).not_to be_nil
      expect(result.text).to eq("Hello world")
    end

    it "returns nil for corrupted cache files" do
      clause = build_clause
      path = File.join(cache_dir, document_id, "#{cache.send(:cache_key, document_id, clause)}.json")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "not valid json {{{")

      result = cache.fetch(document_id, clause)
      expect(result).to be_nil
    end
  end

  describe "#cached?" do
    it "returns true for cached clauses" do
      clause = build_clause
      cache.store(document_id, clause, build_annotated)
      expect(cache.cached?(document_id, clause)).to be true
    end

    it "returns false for uncached clauses" do
      clause = build_clause
      expect(cache.cached?(document_id, clause)).to be false
    end
  end

  describe "#partition" do
    it "splits pairs into cached and uncached" do
      clause1 = build_clause(text: "First clause", id: "c1")
      clause2 = build_clause(text: "Second clause", id: "c2")
      clause3 = build_clause(text: "Third clause", id: "c3")

      ideational1 = SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "c1", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: { root: "x" }
      )

      # Cache only clause1
      cache.store(document_id, clause1, build_annotated(text: "First clause", id: "c1"))

      pairs = [
        [clause1, ideational1],
        [clause2, ideational1],
        [clause3, ideational1]
      ]

      cached_results, uncached_pairs = cache.partition(document_id, pairs)

      expect(cached_results.size).to eq(1)
      expect(cached_results.first.text).to eq("First clause")
      expect(uncached_pairs.size).to eq(2)
      expect(uncached_pairs.map { |c, _| c.id }).to eq(%w[c2 c3])
    end
  end

  describe "#count" do
    it "returns 0 for empty document" do
      expect(cache.count(document_id)).to eq(0)
    end

    it "counts cached clauses" do
      3.times do |i|
        clause = build_clause(text: "Clause #{i}", id: "c#{i}")
        cache.store(document_id, clause, build_annotated(text: "Clause #{i}", id: "c#{i}"))
      end

      expect(cache.count(document_id)).to eq(3)
    end
  end

  describe "#clear" do
    it "removes all cached data for a document" do
      clause = build_clause
      cache.store(document_id, clause, build_annotated)
      expect(cache.count(document_id)).to eq(1)

      cache.clear(document_id)
      expect(cache.count(document_id)).to eq(0)
    end

    it "does not affect other documents" do
      clause1 = build_clause(text: "Doc1 clause", id: "c1")
      clause2 = build_clause(text: "Doc2 clause", id: "c2")

      cache.store("doc-1", clause1, build_annotated(text: "Doc1 clause", id: "c1"))
      cache.store("doc-2", clause2, build_annotated(text: "Doc2 clause", id: "c2"))

      cache.clear("doc-1")
      expect(cache.count("doc-1")).to eq(0)
      expect(cache.count("doc-2")).to eq(1)
    end
  end

  describe "#clear_all" do
    it "removes all cached data" do
      clause = build_clause
      cache.store(document_id, clause, build_annotated)

      cache.clear_all
      expect(cache.count(document_id)).to eq(0)
    end
  end

  describe "round-trip with textual payload" do
    it "preserves textual theme/rheme annotations" do
      clause = build_clause
      annotated = build_annotated

      textual = SFL::Compiler::Types::TextualPayload.new(
        clause_id: "clause-1",
        topical_theme: "The cat",
        textual_theme: nil,
        interpersonal_theme: nil,
        rheme: "sat on the mat",
        theme_type: "unmarked"
      )
      annotated_with_textual = annotated.new(textual: textual)

      cache.store(document_id, clause, annotated_with_textual)
      result = cache.fetch(document_id, clause)

      expect(result.textual).not_to be_nil
      expect(result.textual.topical_theme).to eq("The cat")
      expect(result.textual.rheme).to eq("sat on the mat")
      expect(result.textual.theme_type).to eq("unmarked")
    end
  end
end
