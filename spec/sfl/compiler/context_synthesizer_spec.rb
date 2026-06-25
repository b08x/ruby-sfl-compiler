# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::ContextSynthesizer do
  let(:retriever) { instance_double(SFL::Compiler::HybridRetriever) }
  let(:clause_repo) { instance_double(SFL::Compiler::ClauseRepository) }

  let(:rows) do
    [
      { clause_id: "c-1", text: "Tenor measures formality.", document_id: "d#a", rrf_score: 0.03 },
      { clause_id: "c-2", text: "Mood is the clause type.", document_id: "d#b", rrf_score: 0.02 }
    ]
  end

  before do
    allow(clause_repo).to receive(:find) do |id|
      {
        clause: { external_id: id, text: "..." },
        ideational: { process_type: "relational" },
        interpersonal: { mood: "declarative", tenor: 0.7, modality_weight: 0.8 },
        embedding: nil
      }
    end
  end

  it "short-circuits on empty retrieval without calling the synthesizer" do
    allow(retriever).to receive(:retrieve).and_return([])
    synthesizer = ->(_q, _e) { raise "must not be called" }

    result = described_class.new(retriever: retriever, clause_repo: clause_repo,
      synthesizer: synthesizer).synthesize("anything")

    expect(result.answer).to be_nil
    expect(result.retrieved_count).to eq(0)
  end

  it "passes filters and limit through to the retriever" do
    allow(retriever).to receive(:retrieve).and_return([])
    described_class.new(retriever: retriever, clause_repo: clause_repo,
      synthesizer: ->(_q, _e) {}).synthesize("q", filters: { mood: "declarative" }, limit: 5)

    expect(retriever).to have_received(:retrieve)
      .with("q", limit: 5, filters: { mood: "declarative" })
  end

  it "builds numbered evidence with SFL annotations and maps citations back to ids" do
    allow(retriever).to receive(:retrieve).and_return(rows)
    seen_evidence = nil
    synthesizer = lambda do |_query, evidence|
      seen_evidence = evidence
      { answer: "Tenor is formality.", cited_clause_numbers: [1, 99], confidence: 0.9 }
    end

    result = described_class.new(retriever: retriever, clause_repo: clause_repo,
      synthesizer: synthesizer).synthesize("what is tenor?")

    expect(seen_evidence).to include("[1] Tenor measures formality.")
    expect(seen_evidence).to include("mood=declarative")
    expect(seen_evidence).to include("tenor=0.7")
    # out-of-range citation 99 dropped, 1 maps to c-1
    expect(result.cited_clause_ids).to eq(["c-1"])
    expect(result.answer).to eq("Tenor is formality.")
    expect(result.confidence).to eq(0.9)
    expect(result.retrieved_count).to eq(2)
  end

  it "tolerates clause ids the repository can no longer find" do
    allow(retriever).to receive(:retrieve).and_return(rows)
    allow(clause_repo).to receive(:find).and_return(nil)
    synthesizer = ->(_q, evidence) {
      expect(evidence).to include("[1] Tenor measures formality.")
      { answer: "ok", cited_clause_numbers: [1], confidence: 0.5 }
    }

    result = described_class.new(retriever: retriever, clause_repo: clause_repo,
      synthesizer: synthesizer).synthesize("q")
    expect(result.answer).to eq("ok")
  end

  describe "annotation_source awareness" do
    let(:rows) do
      [
        { clause_id: "c-1", text: "Llm-sourced clause.", document_id: "d#a", rrf_score: 0.03 },
        { clause_id: "c-2", text: "Fallback-sourced clause.", document_id: "d#b", rrf_score: 0.02 }
      ]
    end

    before do
      allow(clause_repo).to receive(:find) do |id|
        source = id == "c-2" ? "fallback" : "llm"
        {
          clause: { external_id: id, text: "..." },
          ideational: { process_type: "relational" },
          interpersonal: { mood: "declarative", tenor: 0.7, modality_weight: 0.8, annotation_source: source },
          embedding: nil
        }
      end
    end

    it "excludes fallback clauses from evidence and citations by default" do
      allow(retriever).to receive(:retrieve).and_return(rows)
      seen_evidence = nil
      synthesizer = lambda do |_query, evidence|
        seen_evidence = evidence
        { answer: "ok", cited_clause_numbers: [1], confidence: 0.9 }
      end

      result = described_class.new(retriever: retriever, clause_repo: clause_repo,
        synthesizer: synthesizer).synthesize("q")

      expect(seen_evidence).to include("Llm-sourced clause.")
      expect(seen_evidence).not_to include("Fallback-sourced clause.")
      expect(result.cited_clause_ids).to eq(["c-1"])
      expect(result.answer).to start_with("_Data Quality: 1/2 retrieved clauses excluded due to fallback annotation._")
      expect(result.clauses.size).to eq(2)
    end

    it "includes fallback clauses when include_fallback: true" do
      allow(retriever).to receive(:retrieve).and_return(rows)
      seen_evidence = nil
      synthesizer = lambda do |_query, evidence|
        seen_evidence = evidence
        { answer: "ok", cited_clause_numbers: [1, 2], confidence: 0.9 }
      end

      result = described_class.new(retriever: retriever, clause_repo: clause_repo,
        synthesizer: synthesizer).synthesize("q", include_fallback: true)

      expect(seen_evidence).to include("Fallback-sourced clause.")
      expect(result.cited_clause_ids).to match_array(%w[c-1 c-2])
      expect(result.answer).to eq("ok")
    end

    it "never cites a fallback clause id even if the synthesizer hallucinates a matching evidence number" do
      allow(retriever).to receive(:retrieve).and_return(rows)
      # Only c-1 is citable (numbered [1]); a "citation" to number 2 has
      # nothing to resolve to since fallback rows aren't in the numbered
      # evidence at all — structurally impossible to cite c-2.
      synthesizer = ->(_q, _e) { { answer: "ok", cited_clause_numbers: [1, 2], confidence: 0.5 } }

      result = described_class.new(retriever: retriever, clause_repo: clause_repo,
        synthesizer: synthesizer).synthesize("q")

      expect(result.cited_clause_ids).to eq(["c-1"])
    end

    it "short-circuits without calling the synthesizer when every retrieved clause is fallback-sourced" do
      allow(retriever).to receive(:retrieve).and_return(rows)
      allow(clause_repo).to receive(:find).and_return(
        clause: { external_id: "c-1", text: "..." },
        ideational: { process_type: "relational" },
        interpersonal: { mood: "declarative", tenor: 0.7, modality_weight: 0.8, annotation_source: "fallback" },
        embedding: nil
      )
      synthesizer = ->(_q, _e) { raise "must not be called" }

      result = described_class.new(retriever: retriever, clause_repo: clause_repo,
        synthesizer: synthesizer).synthesize("q")

      expect(result.answer).to eq("_Data Quality: 2/2 retrieved clauses excluded due to fallback annotation._")
      expect(result.cited_clause_ids).to eq([])
    end
  end

  it "returns a degraded result when the synthesizer output violates the type contract" do
    allow(retriever).to receive(:retrieve).and_return(rows)
    synthesizer = ->(_q, _e) { { answer: 42, cited_clause_numbers: [], confidence: 0.5 } }

    result = nil
    expect {
      result = described_class.new(retriever: retriever, clause_repo: clause_repo,
        synthesizer: synthesizer).synthesize("q")
    }.to output(/\[WARN\]/).to_stderr

    expect(result.answer).to be_nil
    expect(result.retrieved_count).to eq(2)
    expect(result.clauses.size).to eq(2)
  end
end
