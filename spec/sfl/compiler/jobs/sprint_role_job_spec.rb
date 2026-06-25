# frozen_string_literal: true

require "spec_helper"
require "gush"
require "dspy"

RSpec.describe SFL::Compiler::SprintRoleJob do
  before { stub_const("FakeSprintSignature", Class.new) }

  let(:config) { Struct.new(:lm).new }
  let(:predictor) { instance_double(DSPy::ChainOfThought) }
  let(:result) { instance_double(DSPy::Prediction, to_h: { "grounded_claims" => ["x"] }) }

  before do
    allow(DSPy::ChainOfThought).to receive(:new).with(FakeSprintSignature).and_return(predictor)
    allow(predictor).to receive(:configure).and_yield(config)
    allow(predictor).to receive(:call).and_return(result)
    allow(SFL::Compiler::Bootstrap).to receive(:api_key_for).and_return("test-key")
  end

  def job_for(role, lm_provider)
    described_class.new(
      params: {
        role:,
        signature_class: "FakeSprintSignature",
        lm: lm_provider,
        input: { "text" => "the committee approved it" },
      }
    )
  end

  it "configures the predictor's LM per-instance with the given provider string" do
    job = job_for(:achilles, "openrouter/model-a")

    job.perform

    expect(config.lm).to be_a(DSPy::LM)
    expect(SFL::Compiler::Bootstrap).to have_received(:api_key_for).with("openrouter/model-a", ENV)
  end

  it "outputs a JSON-round-trippable Hash from the prediction" do
    job = job_for(:genie, "openrouter/model-c")

    job.perform

    expect(job.output_payload).to eq({ "grounded_claims" => ["x"] })
    expect { JSON.generate(job.output_payload) }.not_to raise_error
  end

  it "calls the predictor with symbolized input keys" do
    job = job_for(:tortoise, "openrouter/model-b")

    job.perform

    expect(predictor).to have_received(:call).with(text: "the committee approved it")
  end

  it "has no prior_output to merge when payloads is unset (Achilles has no dependency)" do
    job = job_for(:achilles, "openrouter/model-a")

    job.perform

    expect(predictor).to have_received(:call).with(text: "the committee approved it")
  end

  it "merges the prior role's output into input under prior_output_key for a dependent role" do
    job = described_class.new(
      params: {
        role: :tortoise,
        signature_class: "FakeSprintSignature",
        lm: "openrouter/model-b",
        input: { "text" => "the committee approved it" },
        prior_output_key: "draft",
      }
    )
    job.payloads = [{ id: "achilles-1", class: "SFL::Compiler::SprintRoleJob", output: { "narrative" => "..." } }]

    job.perform

    expect(predictor).to have_received(:call)
      .with(text: "the committee approved it", draft: { "narrative" => "..." })
  end

  it "gives each role's job its own distinct LM provider — no shared global LM state" do
    lms = %i[achilles tortoise genie].zip(%w[openrouter/a openrouter/b openrouter/c]).map do |role, provider|
      cfg = Struct.new(:lm).new
      allow(predictor).to receive(:configure).and_yield(cfg)

      job_for(role, provider).perform
      cfg.lm
    end

    expect(lms.map(&:model_id).uniq.size).to eq(3)
  end
end
