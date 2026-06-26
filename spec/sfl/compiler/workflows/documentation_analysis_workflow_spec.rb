# frozen_string_literal: true

require "spec_helper"
require "sequel"

RSpec.describe SFL::Compiler::DocumentationAnalysisWorkflow do
  let(:doc_path) { "spec/fixtures/docs/sample.md" }
  let(:pipeline)  { instance_double(SFL::Compiler::Pipeline) }
  let(:db)        { instance_double(Sequel::Database) }
  let(:bootstrap_context) do
    SFL::Compiler::Bootstrap::Context.new(db:, config: SFL::Compiler::Configuration.new)
  end

  let(:token) do
    SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
  end

  def annotated_clause(doc_id)
    syntactic = SFL::Compiler::Types::SyntacticClause.new(
      id: "syn-#{doc_id}", text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: doc_id
    )
    SFL::Compiler::Types::AnnotatedClause.new(
      id: "ann-#{doc_id}", text: "It works.", syntactic:,
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "syn-#{doc_id}", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "syn-#{doc_id}", mood: "declarative",
        modality_weight: 0.6, tenor: 0.7,
        speaker_attitude: nil, reasoning: nil, annotation_source: "llm"
      ),
      document_id: doc_id, compiled_at: Time.now
    )
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
    allow(SFL::Compiler::Pipeline).to receive(:new).and_return(pipeline)
    allow(pipeline).to receive(:compile) { |_text, document_id:, **| [annotated_clause(document_id)] }
  end

  it "fans out one CompileSectionJob per section and reduces to one result" do
    flow = described_class.create(doc_path)
    flow.start!
    flow.reload

    expect(flow.status).to eq(:finished)

    compile_jobs = flow.jobs.select { |j| j.klass.to_s == "SFL::Compiler::CompileSectionJob" }
    # sample.md has 3 ATX headings → 3 sections
    expect(compile_jobs.size).to eq(3)

    reduce_job = flow.jobs.find { |j| j.klass.to_s == "SFL::Compiler::ReduceSectionsJob" }
    expect(reduce_job.output_payload[:section_count]).to eq(3)
    expect(reduce_job.output_payload[:metadata][:total]).to eq(3)
  end

  it "does not include a TopicModelJob (topics: not yet supported for documentation workflows)" do
    flow = described_class.create(doc_path)
    flow.start!
    flow.reload

    job_classes = flow.jobs.map { |j| j.klass.to_s }
    expect(job_classes).not_to include("SFL::Compiler::TopicModelJob")
  end
end
