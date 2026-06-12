# frozen_string_literal: true

require "spec_helper"
require "time"

RSpec.describe SFL::Compiler::Formatters::MarkdownFormatter do
  let(:alice_profile) do
    SFL::Compiler::Types::SpeakerProfile.new(
      speaker_name: "Alice",
      turn_count: 3,
      avg_tenor: 0.38,
      tenor_range: [0.22, 0.61],
      tenor_variance: 0.14,
      avg_modality: 0.42,
      mood_distribution: { "declarative" => 0.72 },
      dominant_processes: { "mental" => 10 }
    )
  end

  let(:bob_profile) do
    SFL::Compiler::Types::SpeakerProfile.new(
      speaker_name: "Bob",
      turn_count: 2,
      avg_tenor: 0.71,
      tenor_range: [0.55, 0.85],
      tenor_variance: 0.09,
      avg_modality: 0.78,
      mood_distribution: { "declarative" => 1.0 },
      dominant_processes: { "verbal" => 8 }
    )
  end

  let(:result) do
    SFL::Compiler::Types::AnalysisResult.new(
      metadata: {
        conversation_id: "test-convo",
        turn_count: 5,
        speakers: ["Alice", "Bob"],
        analyzed_at: Time.parse("2026-06-10 14:32:15")
      },
      turns: [],
      speaker_profiles: { "Alice" => alice_profile, "Bob" => bob_profile },
      tenor_timeline: [],
      field_evolution: [],
      correlations: {
        "mental" => { avg_tenor: 0.34, avg_modality: 0.41, count: 10 },
        "verbal" => { avg_tenor: 0.71, avg_modality: 0.78, count: 8 }
      },
      insights: [
        "Alice maintains casual tenor across conversation",
        "Mental processes correlate with low tenor"
      ]
    )
  end

  subject(:output) { described_class.new(result).render }

  # Extract a section by its ## header, returning the content between
  # this header and the next ## header. Tolerates different line endings.
  def section(after_header)
    parts = output.split(/^##\s+/)
    found = parts.find { |p| p.start_with?(after_header) }
    return "" unless found

    found.split("\n", 2).last.to_s
  end

  describe "regression: \\\\n literal in table separators" do
    it "speaker_profiles separator ends with a real newline, not a literal backslash-n" do
      speaker_section = section("Speaker Profiles")
      expect(speaker_section).to include("|---")
      expect(speaker_section).not_to include("\\n")
    end

    it "correlations separator ends with a real newline, not a literal backslash-n" do
      corr_section = section("Tenor ↔ Field Correlations")
      expect(corr_section).to include("|---")
      expect(corr_section).not_to include("\\n")
    end

    it "output contains no literal backslash-n anywhere" do
      expect(output).not_to match(/\\n/)
    end
  end

  describe "rendered tables" do
    it "renders speaker profiles as a valid markdown table with 2 data rows" do
      speaker_section = section("Speaker Profiles")
      lines = speaker_section.lines.map(&:chomp)

      header_line = lines.find { |l| l.start_with?("| Speaker ") }
      separator_line = lines.find { |l| l.start_with?("|---") }
      data_lines = lines.select { |l| l.start_with?("| Alice") || l.start_with?("| Bob") }

      expect(header_line).to eq("| Speaker | Avg Tenor | Range | Variance | Avg Modality |")
      expect(separator_line).to eq("|---------|-----------|-------|----------|--------------|")
      expect(data_lines.length).to eq(2)
      expect(data_lines).to include(a_string_starting_with("| Alice |"))
      expect(data_lines).to include(a_string_starting_with("| Bob |"))
    end

    it "renders correlations as a valid markdown table with 2 data rows" do
      corr_section = section("Tenor ↔ Field Correlations")
      lines = corr_section.lines.map(&:chomp)

      header_line = lines.find { |l| l.start_with?("| Process Type ") }
      separator_line = lines.find { |l| l.start_with?("|---") }
      data_lines = lines.select { |l| l.start_with?("| mental") || l.start_with?("| verbal") }

      expect(header_line).to eq("| Process Type | Avg Tenor | Avg Modality | Count |")
      expect(separator_line).to eq("|--------------|-----------|--------------|-------|")
      expect(data_lines.length).to eq(2)
    end

    it "renders insights as a numbered list" do
      expect(output).to include("1. Alice maintains casual tenor across conversation")
      expect(output).to include("2. Mental processes correlate with low tenor")
    end
  end

  describe "empty data fallbacks" do
    let(:empty_result) do
      SFL::Compiler::Types::AnalysisResult.new(
        metadata: {
          conversation_id: "empty-convo",
          turn_count: 0,
          speakers: [],
          analyzed_at: Time.now
        },
        turns: [],
        speaker_profiles: {},
        tenor_timeline: [],
        field_evolution: [],
        correlations: {},
        insights: []
      )
    end

    it "renders speaker profiles fallback when empty" do
      out = described_class.new(empty_result).render
      expect(out).to include("## Speaker Profiles")
      expect(out).to include("_No speaker profiles available_")
    end

    it "renders correlations fallback when empty" do
      out = described_class.new(empty_result).render
      expect(out).to include("## Tenor ↔ Field Correlations")
      expect(out).to include("_No correlations available_")
    end

    it "renders insights fallback when empty" do
      out = described_class.new(empty_result).render
      expect(out).to include("## Generated Insights")
      expect(out).to include("_No insights generated_")
    end
  end

  describe "data quality warning" do
    def annotated_clause(source)
      token = SFL::Compiler::Types::SyntacticToken.new(
        text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
        dep: "ROOT", head_index: -1, morphology: {}, index: 0
      )
      syntactic = SFL::Compiler::Types::SyntacticClause.new(
        id: "syn-1", text: "It works.", tokens: [token],
        root_index: 0, sentence_index: 0, document_id: "doc-1"
      )
      ideational = SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "syn-1", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      )
      interpersonal = SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "syn-1", mood: "declarative",
        modality_weight: 0.5, tenor: 0.5,
        speaker_attitude: nil, reasoning: nil,
        annotation_source: source
      )
      SFL::Compiler::Types::AnnotatedClause.new(
        id: "ann-1", text: "It works.", syntactic: syntactic,
        ideational: ideational, interpersonal: interpersonal,
        document_id: "doc-1", compiled_at: Time.now
      )
    end

    def turn_with(clauses)
      SFL::Compiler::Types::ConversationTurn.new(
        turn_id: 1, speaker: "Alice", timestamp: Time.now,
        message_text: "It works.", clauses: clauses,
        avg_tenor: 0.5, avg_modality: 0.5, dominant_mood: "declarative",
        process_types: {}, participants: [], tenor_shift: nil
      )
    end

    def result_with_clauses(clauses)
      SFL::Compiler::Types::AnalysisResult.new(
        metadata: { conversation_id: "q", turn_count: 1, speakers: ["Alice"], analyzed_at: Time.now },
        turns: [turn_with(clauses)],
        speaker_profiles: {}, tenor_timeline: [], field_evolution: [],
        correlations: {}, insights: []
      )
    end

    it "renders no warning when all clauses are llm-annotated" do
      out = described_class.new(result_with_clauses([annotated_clause("llm")])).render
      expect(out).not_to include("Data Quality")
    end

    it "renders no warning when turns carry no clauses" do
      expect(output).not_to include("Data Quality")
    end

    it "warns with counts when some clauses carry fallback or stub values" do
      clauses = [annotated_clause("llm"), annotated_clause("llm"), annotated_clause("llm"), annotated_clause("fallback")]
      out = described_class.new(result_with_clauses(clauses)).render
      expect(out).to include("## ⚠️ Data Quality")
      expect(out).to include("1 of 4 clauses (25.0%)")
    end

    it "states that Pass 2 did not run when every clause is defaulted" do
      clauses = [annotated_clause("stub"), annotated_clause("stub")]
      out = described_class.new(result_with_clauses(clauses)).render
      expect(out).to include("2 of 2 clauses (100.0%)")
      expect(out).to include("Pass 2 did not run")
      expect(out).to include("placeholders, not findings")
    end
  end

  describe "metadata header" do
    it "includes conversation_id, generated timestamp, turn_count, and speakers" do
      expect(output).to include("# Conversation Analysis: test-convo")
      expect(output).to include("**Turns**: 5")
      expect(output).to include("**Speakers**: Alice, Bob")
    end
  end
end