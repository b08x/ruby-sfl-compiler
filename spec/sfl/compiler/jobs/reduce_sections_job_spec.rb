# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::ReduceSectionsJob do
  let(:section_1) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 1, speaker: "Introduction", timestamp: Time.now,
      message_text: "This introduces the system.", clauses: [], avg_tenor: 0.5,
      avg_modality: 0.5, dominant_mood: "declarative", process_types: {},
      participants: [], tenor_shift: nil
    )
  end

  let(:section_2) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 2, speaker: "Usage", timestamp: Time.now,
      message_text: "Users invoke the tool.", clauses: [], avg_tenor: 0.6,
      avg_modality: 0.4, dominant_mood: "declarative", process_types: {},
      participants: [], tenor_shift: nil
    )
  end

  it "reconstructs sections from payloads and outputs AnalysisResult metadata" do
    job = described_class.new(
      params: { path: "spec/fixtures/docs/sample.md", total: 2 }
    )
    job.payloads = [
      { id: "CompileSectionJob-1", class: "SFL::Compiler::CompileSectionJob",
        output: SFL::Compiler::Types.dump(section_1) },
      { id: "CompileSectionJob-2", class: "SFL::Compiler::CompileSectionJob",
        output: SFL::Compiler::Types.dump(section_2) },
    ]

    job.perform

    expect(job.output_payload[:section_count]).to eq(2)
    expect(job.output_payload[:metadata][:speakers]).to match_array(%w[Introduction Usage])
    expect(job.output_payload[:metadata][:unit_label]).to eq("Section")
  end

  it "forwards full AnalysisResult fields in output" do
    job = described_class.new(
      params: { path: "spec/fixtures/docs/sample.md", total: 2 }
    )
    job.payloads = [
      { id: "CompileSectionJob-1", class: "SFL::Compiler::CompileSectionJob",
        output: SFL::Compiler::Types.dump(section_1) },
      { id: "CompileSectionJob-2", class: "SFL::Compiler::CompileSectionJob",
        output: SFL::Compiler::Types.dump(section_2) },
    ]

    job.perform

    payload = job.output_payload
    expect(payload).to include(:speaker_profiles, :tenor_timeline, :field_evolution, :correlations)
    expect(payload).to include(:key_moments, :example_passages, :topic_labels, :topic_evolution)
    expect(payload[:tenor_timeline]).to be_an(Array)
    expect(payload[:key_moments]).to be_an(Array)
  end

  it "sets interrupted: true when fewer sections compiled than total" do
    job = described_class.new(
      params: { path: "spec/fixtures/docs/sample.md", total: 5 }
    )
    job.payloads = [
      { id: "CompileSectionJob-1", class: "SFL::Compiler::CompileSectionJob",
        output: SFL::Compiler::Types.dump(section_1) },
    ]

    job.perform

    expect(job.output_payload[:metadata][:interrupted]).to be(true)
  end

  it "passes sections_meta to build_result for chunk-artifact detection" do
    sections_meta = [
      { file_id: "report", heading: "Intro", pdf_chunk: true },
      { file_id: "report", heading: "Body",  pdf_chunk: true },
    ]

    job = described_class.new(
      params: { path: "spec/fixtures/docs/sample.md", total: 2, sections_meta: }
    )
    job.payloads = [
      { id: "CompileSectionJob-1", class: "SFL::Compiler::CompileSectionJob",
        output: SFL::Compiler::Types.dump(section_1) },
      { id: "CompileSectionJob-2", class: "SFL::Compiler::CompileSectionJob",
        output: SFL::Compiler::Types.dump(section_2) },
    ]

    expect { job.perform }.not_to raise_error
    expect(job.output_payload[:section_count]).to eq(2)
  end

  it "forwards topic_labels/topic_shifts into build_result when a TopicModelJob payload is present" do
    job = described_class.new(
      params: { path: "spec/fixtures/docs/sample.md", total: 2 }
    )
    job.payloads = [
      { id: "CompileSectionJob-1", class: "SFL::Compiler::CompileSectionJob",
        output: SFL::Compiler::Types.dump(section_1) },
      { id: "CompileSectionJob-2", class: "SFL::Compiler::CompileSectionJob",
        output: SFL::Compiler::Types.dump(section_2) },
      {
        id: "TopicModelJob-1",
        class: "SFL::Compiler::TopicModelJob",
        output: {
          pre_turns: [],
          topic_labels: { 0 => %w[architecture pipeline] },
          topic_shifts: [],
        },
      },
    ]

    job.perform

    expect(job.output_payload[:metadata][:topics_enabled]).to be(true)
  end
end
