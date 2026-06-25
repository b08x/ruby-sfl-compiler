# frozen_string_literal: true

require "spec_helper"
require "gush"
require "dspy"

RSpec.describe SFL::Compiler::SprintWorkflow do
  before do
    stub_const("FixturePropose", Class.new)
    stub_const("FixtureChallenge", Class.new)
    stub_const("FixtureSynthesize", Class.new)
  end

  let(:achilles_result) { instance_double(DSPy::Prediction, to_h: { "claims" => [{ "modality_weight" => 0.9 }] }) }
  let(:tortoise_result) { instance_double(DSPy::Prediction, to_h: { "claims" => [{ "modality_weight" => 0.9 }] }) }
  let(:genie_result) { instance_double(DSPy::Prediction, to_h: { "final" => true }) }

  let(:achilles_predictor) { instance_double(DSPy::ChainOfThought, configure: nil, call: achilles_result) }
  let(:tortoise_predictor) { instance_double(DSPy::ChainOfThought, configure: nil, call: tortoise_result) }
  let(:genie_predictor) { instance_double(DSPy::ChainOfThought, configure: nil, call: genie_result) }

  def base_payload(invariants: [])
    {
      input: { "text" => "the committee approved it" },
      propose_signature: "FixturePropose",
      challenge_signature: "FixtureChallenge",
      synthesize_signature: "FixtureSynthesize",
      achilles_lm: "openrouter/model-a",
      tortoise_lm: "openrouter/model-b",
      genie_lm: "openrouter/model-c",
      invariants:,
    }
  end

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    Gush.configure { |c| c.redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379") }
    example.run
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  before do
    allow(SFL::Compiler::Bootstrap).to receive(:call).and_call_original
    allow(SFL::Compiler::Bootstrap).to receive(:api_key_for).and_return("test-key")
    allow(DSPy::ChainOfThought).to receive(:new).with(FixturePropose).and_return(achilles_predictor)
    allow(DSPy::ChainOfThought).to receive(:new).with(FixtureChallenge).and_return(tortoise_predictor)
    allow(DSPy::ChainOfThought).to receive(:new).with(FixtureSynthesize).and_return(genie_predictor)
  end

  it "runs Achilles -> Tortoise -> Crab -> Genie end-to-end and produces a Genie output reflecting Crab's filtering" do
    flow = described_class.create(base_payload)
    flow.start!
    flow.reload

    expect(flow.status).to eq(:finished)

    genie_job = flow.jobs.select { |j| j.klass.to_s == "SFL::Compiler::SprintRoleJob" }.last
    # Each job's output is JSON round-tripped through Redis before the next
    # job reads it as a `payloads` entry (Gush::Worker rebuilds the job's
    # incoming_payloads from persisted state) — string keys on the way in
    # come back as symbols (symbolize_names), same as
    # ConversationAnalysisWorkflow's own spec asserting on output_payload
    # with symbol keys.
    expect(genie_job.output_payload).to eq({ final: true })
    expect(genie_predictor).to have_received(:call)
      .with(hash_including(prior_output: {
        passed_claims: [{ modality_weight: 0.9 }],
        rejected_claims: [],
        violations: [],
      }))
  end

  it "produces a structurally identical run with a different domain_payload (different signatures/invariants)" do
    stub_const("OtherPropose", Class.new)
    stub_const("OtherChallenge", Class.new)
    stub_const("OtherSynthesize", Class.new)
    allow(DSPy::ChainOfThought).to receive(:new).with(OtherPropose).and_return(achilles_predictor)
    allow(DSPy::ChainOfThought).to receive(:new).with(OtherChallenge).and_return(tortoise_predictor)
    allow(DSPy::ChainOfThought).to receive(:new).with(OtherSynthesize).and_return(genie_predictor)

    other_payload = base_payload.merge(
      propose_signature: "OtherPropose",
      challenge_signature: "OtherChallenge",
      synthesize_signature: "OtherSynthesize",
      invariants: [{ "name" => "min_modality", "field" => "modality_weight", "op" => "gte", "value" => 0.5 }]
    )

    flow = described_class.create(other_payload)
    flow.start!
    flow.reload

    expect(flow.status).to eq(:finished)
    genie_job = flow.jobs.select { |j| j.klass.to_s == "SFL::Compiler::SprintRoleJob" }.last
    expect(genie_job.output_payload).to eq({ final: true })
  end
end
