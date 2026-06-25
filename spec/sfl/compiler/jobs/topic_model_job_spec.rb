# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::TopicModelJob do
  let(:jsonl_path) { "spec/fixtures/conversations/sample.jsonl" }

  it "fits a TopicModeler over the raw turns and outputs JSON-safe pre_turns/topic_labels/topic_shifts" do
    job = described_class.new(params: { jsonl_path:, topics: 2 })

    job.perform

    payload = JSON.parse(JSON.generate(job.output_payload), symbolize_names: true)
    expect(payload[:pre_turns].size).to eq(5)
    expect(payload[:pre_turns].first).to include(:turn_id, :dominant_topic, :topic_distribution)
    # JSON object keys are always strings — confirms why CompileTurnJob/
    # ReduceTurnsJob both restore Integer keys via transform_keys before
    # indexing topic_labels by dominant_topic (an Integer value).
    expect(payload[:topic_labels].keys).to all(satisfy { |k| !k.is_a?(Integer) })
    expect(payload[:topic_shifts]).to be_an(Array)
  end

  it "maps topics: 0 to HDP (k: nil), matching ConversationAnalyzer#topic_k" do
    modeler = instance_double(SFL::Compiler::Analysis::TopicModeler, fit: nil, turns: [], topic_labels: {},
      detect_topic_shifts: [])
    allow(SFL::Compiler::Analysis::TopicModeler).to receive(:new).and_return(modeler)

    described_class.new(params: { jsonl_path:, topics: 0 }).perform

    expect(SFL::Compiler::Analysis::TopicModeler).to have_received(:new).with(k: nil)
  end
end
