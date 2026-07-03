# frozen_string_literal: true

require "spec_helper"
require "sequel"

RSpec.describe SFL::Compiler::ReannotateClauseWorkflow do
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
  let(:reannotated_clause) do
    SFL::Compiler::Types::AnnotatedClause.new(
      id: "clause-1", text: "It works.", syntactic:, ideational:,
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "clause-1", mood: "interrogative", modality_weight: 0.9, tenor: 0.8,
        speaker_attitude: nil, reasoning: nil, annotation_source: "llm"
      ),
      document_id: "doc-1", compiled_at: Time.now
    )
  end

  let(:clause_repo) { instance_double(SFL::Compiler::ClauseRepository) }
  let(:pass_two) { instance_double(SFL::Compiler::PassTwoEngine) }
  let(:db) { instance_double(Sequel::Database) }
  let(:bootstrap_context) do
    SFL::Compiler::Bootstrap::Context.new(db:, config: SFL::Compiler::Configuration.new)
  end

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    Gush.configure { |c| c.redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379") }
    example.run
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  before do
    allow(SFL::Compiler::Bootstrap).to receive(:call).and_return(bootstrap_context)
    allow(SFL::Compiler::ClauseRepository).to receive(:new).and_return(clause_repo)
    allow(SFL::Compiler::PassTwoEngine).to receive(:new).and_return(pass_two)
    allow(clause_repo).to receive(:find_pass_one_output).with("clause-1").and_return(syntactic:, ideational:)
    allow(clause_repo).to receive(:find).with("clause-1").and_return(interpersonal: { annotation_source: "fallback" })
    allow(pass_two).to receive(:annotate).and_return(reannotated_clause)
    allow(clause_repo).to receive(:update_interpersonal)
    allow(clause_repo).to receive(:record_review)
  end

  it "runs ReannotateClauseJob to completion through real Gush/Redis" do
    flow = described_class.create(clause_id: "clause-1", reviewer: "bob")
    flow.start!
    flow.reload

    expect(flow.status).to eq(:finished)
    expect(clause_repo).to have_received(:update_interpersonal).with("clause-1", reannotated_clause.interpersonal)
    expect(clause_repo).to have_received(:record_review).with(
      clause_id: "clause-1", decision: "re_annotated", original_annotation_source: "fallback",
      reviewer: "bob", notes: nil
    )
  end
end
