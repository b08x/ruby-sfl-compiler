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
        speakers: %w[Alice Bob],
        analyzed_at: Time.parse("2026-06-10 14:32:15"),
      },
      turns: [],
      speaker_profiles: { "Alice" => alice_profile, "Bob" => bob_profile },
      tenor_timeline: [],
      field_evolution: [],
      correlations: {
        "mental" => { avg_tenor: 0.34, avg_modality: 0.41, count: 10 },
        "verbal" => { avg_tenor: 0.71, avg_modality: 0.78, count: 8 },
      },
      insights: [
        "Alice maintains casual tenor across conversation",
        "Mental processes correlate with low tenor",
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

      expect(header_line).to include("| Speaker | Avg Tenor | Range | Variance | Avg Modality |")
      expect(separator_line).to include("|---------|-----------|-------|----------|--------------|")
      expect(data_lines.length).to eq(2)
      expect(data_lines).to include(a_string_starting_with("| Alice"))
      expect(data_lines).to include(a_string_starting_with("| Bob"))
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
          analyzed_at: Time.now,
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
    def annotated_clause(source, reasoning_trace: nil)
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
        annotation_source: source, reasoning_trace:
      )
      SFL::Compiler::Types::AnnotatedClause.new(
        id: "ann-1", text: "It works.", syntactic:,
        ideational:, interpersonal:,
        document_id: "doc-1", compiled_at: Time.now
      )
    end

    def turn_with(clauses)
      SFL::Compiler::Types::ConversationTurn.new(
        turn_id: 1, speaker: "Alice", timestamp: Time.now,
        message_text: "It works.", clauses:,
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
      clauses = [
        annotated_clause("llm"),
        annotated_clause("llm"),
        annotated_clause("llm"),
        annotated_clause("fallback"),
]
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

    it "counts chunk_artifact clauses separately from fallback/stub" do
      clauses = [
        annotated_clause("llm"),
        annotated_clause("chunk_artifact"),
        annotated_clause("chunk_artifact"),
      ]
      out = described_class.new(result_with_clauses(clauses)).render
      expect(out).to include("## ⚠️ Data Quality")
      expect(out).to include("2 chunk-boundary artifacts excluded.")
      expect(out).not_to include("carry fallback/stub interpersonal values")
    end

    it "renders both the fallback/stub line and the chunk-artifact line when both are present" do
      clauses = [annotated_clause("llm"), annotated_clause("fallback"), annotated_clause("chunk_artifact")]
      out = described_class.new(result_with_clauses(clauses)).render
      expect(out).to include("1 of 3 clauses (33.3%)")
      expect(out).to include("1 chunk-boundary artifacts excluded.")
    end

    describe "reasoning traces section" do
      def reasoning_trace
        SFL::Compiler::Types::ReasoningTrace.new(
          premises: [
            SFL::Compiler::Types::Premise.new(type: "token", source: "unanimously", value: "ADV", weight: 0.7),
            SFL::Compiler::Types::Premise.new(type: "pos", source: "DET+VERB", value: "formal_pattern", weight: nil),
          ],
          inference_rule: "tenor_high_formal_register",
          conclusion: { tenor: 0.8 },
          confidence: 0.92,
          derivation_hash: "a3f2b7c",
          generated_at: Time.now
        )
      end

      it "renders a collapsible details block with all premises for a clause with a populated trace" do
        clause = annotated_clause("llm", reasoning_trace:)
        out = described_class.new(result_with_clauses([clause])).render

        expect(out).to include("### 🔍 Reasoning Traces")
        expect(out).to include("<details>")
        expect(out).to include("<summary>Reasoning: tenor_high_formal_register (confidence 0.92)</summary>")
        expect(out).to include("| unanimously | token | ADV | 0.7 |")
        expect(out).to include("| DET+VERB | pos | formal_pattern | — |")
        expect(out).to include("Derivation: `a3f2b7c`")
        expect(out).to include("</details>")
      end

      it "renders no proof-chain block for a fallback-sourced clause (reasoning_trace: nil)" do
        out = described_class.new(result_with_clauses([annotated_clause("fallback")])).render

        expect(out).not_to include("### 🔍 Reasoning Traces")
        expect(out).not_to include("<details>")
      end

      it "renders no reasoning traces section when there are no traces at all" do
        expect(output).not_to include("### 🔍 Reasoning Traces")
      end
    end
  end

  describe "metadata header" do
    it "includes conversation_id, generated timestamp, turn_count, and speakers" do
      expect(output).to include("# Conversation Analysis: test-convo")
      expect(output).to include("**Turns**: 5")
      expect(output).to include("**Speakers**: Alice, Bob")
    end
  end

  describe "parameterized labels" do
    let(:doc_result) do
      result.new(metadata: result.metadata.merge(
        unit_label: "Section", actor_label: "Section"
      ))
    end

    it "uses actor_label for profile table headers" do
      out = described_class.new(doc_result).render
      expect(out).to include("## Section Profiles")
      expect(out).to include("| Section | Avg Tenor |")
    end

    it "uses unit_label in the header line" do
      out = described_class.new(doc_result).render
      expect(out).to include("**Sections**: 5")
    end

    it "defaults to Speaker/Turn labels when metadata has none" do
      expect(output).to include("## Speaker Profiles")
      expect(output).to include("**Turns**: 5")
    end

    it "uses actors_list_label for the speakers list when provided" do
      labeled = result.new(metadata: result.metadata.merge(actors_list_label: "Headings"))
      out = described_class.new(labeled).render
      expect(out).to include("**Headings**: Alice, Bob")
      expect(out).not_to include("**Speakers**:")
    end
  end

  describe "low confidence banner" do
    it "omits the banner when low_confidence is absent from metadata" do
      expect(output).not_to include("LOW CONFIDENCE")
    end

    it "omits the banner when low_confidence is explicitly false" do
      not_low = result.new(metadata: result.metadata.merge(low_confidence: false, clause_count: 31))
      out = described_class.new(not_low).render
      expect(out).not_to include("LOW CONFIDENCE")
    end

    it "renders the banner with clause count and threshold when low_confidence is true" do
      low = result.new(metadata: result.metadata.merge(
        low_confidence: true, clause_count: 29, low_confidence_threshold: 30
      ))
      out = described_class.new(low).render

      expect(out).to include("LOW CONFIDENCE: 29 clauses (minimum 30 recommended)")
    end
  end

  describe "sprint footer" do
    it "omits the footer when no sprint_id is in metadata" do
      expect(output).not_to include("Sprint G_N")
      expect(output).not_to include("Sprint ID")
    end

    it "renders the sprint footer when sprint_id is present" do
      with_sprint = result.new(metadata: result.metadata.merge(
        sprint_id: "sprint-001",
        sprint_question_ids: %i[modality data_quality overall_confidence]
      ))
      out = described_class.new(with_sprint).render

      expect(out).to include("**Sprint ID**: sprint-001")
      expect(out).not_to include("G_N")
      expect(out).to include("**Questions**: modality, data_quality, overall_confidence")
    end
  end
end
