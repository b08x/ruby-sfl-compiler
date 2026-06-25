# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::ReduceTurnsJob do
  let(:turn_1) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 1, speaker: "Alice", timestamp: Time.now,
      message_text: "Hi.", clauses: [], avg_tenor: 0.5, avg_modality: 0.5,
      dominant_mood: "declarative", process_types: {}, participants: [], tenor_shift: nil
    )
  end

  let(:turn_2) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 2, speaker: "Bob", timestamp: Time.now,
      message_text: "Hello.", clauses: [], avg_tenor: 0.6, avg_modality: 0.4,
      dominant_mood: "declarative", process_types: {}, participants: [], tenor_shift: nil
    )
  end

  it "reconstructs turns from payloads and outputs the AnalysisResult metadata" do
    # Gush::Job#initialize ignores a `payloads:` constructor option (see
    # gush/job.rb#assign_variables) — the real Worker sets it via the
    # `payloads=` accessor after construction (`job.payloads =
    # incoming_payloads`), so the spec must do the same rather than pass
    # it through `.new`.
    job = described_class.new(
      params: { jsonl_path: "spec/fixtures/conversations/sample.jsonl", total: 2 }
    )
    job.payloads = [
      { id: "CompileTurnJob-1", class: "SFL::Compiler::CompileTurnJob", output: SFL::Compiler::Types.dump(turn_1) },
      { id: "CompileTurnJob-2", class: "SFL::Compiler::CompileTurnJob", output: SFL::Compiler::Types.dump(turn_2) },
    ]

    job.perform

    expect(job.output_payload[:turn_count]).to eq(2)
    expect(job.output_payload[:metadata][:speakers]).to match_array(%w[Alice Bob])
  end

  it "forwards topic_labels/topic_shifts into build_result when a TopicModelJob payload is present" do
    job = described_class.new(
      params: { jsonl_path: "spec/fixtures/conversations/sample.jsonl", total: 2 }
    )
    job.payloads = [
      { id: "CompileTurnJob-1", class: "SFL::Compiler::CompileTurnJob", output: SFL::Compiler::Types.dump(turn_1) },
      { id: "CompileTurnJob-2", class: "SFL::Compiler::CompileTurnJob", output: SFL::Compiler::Types.dump(turn_2) },
      {
        id: "TopicModelJob-1",
        class: "SFL::Compiler::TopicModelJob",
        output: {
          pre_turns: [],
          topic_labels: { 0 => %w[deploy pipeline] },
          topic_shifts: [{ turn_id: 2, type: "topic_shift", magnitude: 0.4, description: "shift" }],
        },
      },
    ]

    job.perform

    expect(job.output_payload[:metadata][:topics_enabled]).to be(true)
  end

  it "forwards full AnalysisResult fields in output: speaker_profiles, tenor_timeline, key_moments, example_passages" do
    job = described_class.new(
      params: { jsonl_path: "spec/fixtures/conversations/sample.jsonl", total: 2 }
    )
    job.payloads = [
      { id: "CompileTurnJob-1", class: "SFL::Compiler::CompileTurnJob", output: SFL::Compiler::Types.dump(turn_1) },
      { id: "CompileTurnJob-2", class: "SFL::Compiler::CompileTurnJob", output: SFL::Compiler::Types.dump(turn_2) },
    ]

    job.perform

    payload = job.output_payload
    expect(payload).to include(:speaker_profiles, :tenor_timeline, :field_evolution, :correlations)
    expect(payload).to include(:key_moments, :example_passages, :topic_labels, :topic_evolution)
    expect(payload[:speaker_profiles]).to be_a(Hash)
    expect(payload[:tenor_timeline]).to be_an(Array)
    expect(payload[:key_moments]).to be_an(Array)
    expect(payload[:example_passages]).to be_an(Array)
  end

  it "ignores the TopicModelJob payload's class entirely when reconstructing turns" do
    job = described_class.new(
      params: { jsonl_path: "spec/fixtures/conversations/sample.jsonl", total: 2 }
    )
    job.payloads = [
      { id: "CompileTurnJob-1", class: "SFL::Compiler::CompileTurnJob", output: SFL::Compiler::Types.dump(turn_1) },
      { id: "CompileTurnJob-2", class: "SFL::Compiler::CompileTurnJob", output: SFL::Compiler::Types.dump(turn_2) },
      {
        id: "TopicModelJob-1",
        class: "SFL::Compiler::TopicModelJob",
        output: { pre_turns: [], topic_labels: {}, topic_shifts: [] },
      },
    ]

    expect { job.perform }.not_to raise_error
    expect(job.output_payload[:turn_count]).to eq(2)
  end
end
