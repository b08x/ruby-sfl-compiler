# frozen_string_literal: true

require "spec_helper"
# Same rationale as compile_turn_job_spec.rb: instance_double(Sequel::Database)
# needs the constant loaded, but this spec stubs Bootstrap.call entirely so
# Database is never autoloaded.
require "sequel"

RSpec.describe SFL::Compiler::ReannotateClauseJob do
  let(:token) do
    SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
  end
  let(:syntactic) do
    SFL::Compiler::Types::SyntacticClause.new(
      id: "clause-1", text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: "doc-1"
    )
  end
  let(:ideational) do
    SFL::Compiler::Types::IdeationalPayload.new(
      clause_id: "clause-1", process_type: "material",
      participants: [], circumstances: [], raw_transitivity: {}
    )
  end
  let(:new_interpersonal) do
    SFL::Compiler::Types::InterpersonalPayload.new(
      clause_id: "clause-1", mood: "interrogative", modality_weight: 0.9, tenor: 0.8,
      speaker_attitude: "curious", reasoning: "re-annotated", annotation_source: "llm"
    )
  end
  let(:reannotated_clause) do
    SFL::Compiler::Types::AnnotatedClause.new(
      id: "clause-1", text: "It works.", syntactic:, ideational:,
      interpersonal: new_interpersonal, document_id: "doc-1", compiled_at: Time.now
    )
  end

  let(:clause_repo) { instance_double(SFL::Compiler::ClauseRepository) }
  let(:pass_two) { instance_double(SFL::Compiler::PassTwoEngine) }
  let(:db) { instance_double(Sequel::Database) }
  let(:bootstrap_context) do
    SFL::Compiler::Bootstrap::Context.new(db:, config: SFL::Compiler::Configuration.new)
  end

  before do
    allow(SFL::Compiler::Bootstrap).to receive(:call).and_return(bootstrap_context)
    allow(SFL::Compiler::ClauseRepository).to receive(:new).and_return(clause_repo)
    allow(SFL::Compiler::PassTwoEngine).to receive(:new).and_return(pass_two)
    allow(clause_repo).to receive(:find_pass_one_output).with("clause-1")
      .and_return(syntactic:, ideational:)
    allow(clause_repo).to receive(:find).with("clause-1")
      .and_return(interpersonal: { annotation_source: "fallback" })
    allow(pass_two).to receive(:annotate).and_return(reannotated_clause)
    allow(clause_repo).to receive(:update_interpersonal)
    allow(clause_repo).to receive(:record_review)
  end

  it "re-runs Pass 2 against reconstructed Pass 1 output and persists the new interpersonal payload" do
    job = described_class.new(params: { clause_id: "clause-1" })

    job.perform

    expect(pass_two).to have_received(:annotate).with(syntactic, ideational)
    expect(clause_repo).to have_received(:update_interpersonal).with("clause-1", new_interpersonal)
  end

  it "records a re_annotated review with the original (pre-re-annotation) source snapshotted" do
    job = described_class.new(params: { clause_id: "clause-1", reviewer: "bob", notes: "seemed off" })

    job.perform

    expect(clause_repo).to have_received(:record_review).with(
      clause_id: "clause-1", decision: "re_annotated", original_annotation_source: "fallback",
      reviewer: "bob", notes: "seemed off"
    )
  end

  it "does not force annotation_source to human — the recompiled value stays whatever PassTwoEngine set" do
    job = described_class.new(params: { clause_id: "clause-1" })

    job.perform

    output = SFL::Compiler::Types.load_annotated_clause(
      JSON.parse(JSON.generate(job.output_payload), symbolize_names: true)
    )
    expect(output.interpersonal.annotation_source).to eq("llm")
  end

  it "raises when the clause has no Pass 1 output to reconstruct" do
    allow(clause_repo).to receive(:find_pass_one_output).with("missing").and_return(nil)
    job = described_class.new(params: { clause_id: "missing" })

    expect { job.perform }.to raise_error(ArgumentError, /missing.*not found/)
  end
end
