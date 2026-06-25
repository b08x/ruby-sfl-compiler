# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe SFL::Compiler::Formatters::JSONFormatter do
  let(:alice_profile) do
    SFL::Compiler::Types::SpeakerProfile.new(
      speaker_name: "Alice",
      turn_count: 3,
      avg_tenor: 0.38,
      tenor_range: [0.22, 0.61],
      tenor_variance: 0.14,
      avg_modality: 0.42,
      mood_distribution: { "declarative" => 0.72, "interrogative" => 0.28 },
      dominant_processes: { "mental" => 10, "material" => 5 }
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
      speaker_profiles: { "Alice" => alice_profile },
      tenor_timeline: [
        { timestamp: Time.parse("2026-06-10 14:30"), tenor: 0.32, speaker: "Alice" },
      ],
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

  describe "#render" do
    it "generates valid JSON" do
      formatter = described_class.new(result)
      json_output = formatter.render

      expect { JSON.parse(json_output) }.not_to raise_error
    end

    it "includes metadata" do
      formatter = described_class.new(result)
      json = JSON.parse(formatter.render)

      expect(json["metadata"]["conversation_id"]).to eq("test-convo")
      expect(json["metadata"]["turn_count"]).to eq(5)
      expect(json["metadata"]["speakers"]).to eq(%w[Alice Bob])
    end

    it "includes annotation coverage computed from clause provenance" do
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
      clauses = %w[llm llm fallback stub].map do |source|
        SFL::Compiler::Types::AnnotatedClause.new(
          id: "ann-1", text: "It works.", syntactic:,
          ideational:,
          interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
            clause_id: "syn-1", mood: "declarative",
            modality_weight: 0.5, tenor: 0.5,
            speaker_attitude: nil, reasoning: nil,
            annotation_source: source
          ),
          document_id: "doc-1", compiled_at: Time.now
        )
      end
      turn = SFL::Compiler::Types::ConversationTurn.new(
        turn_id: 1, speaker: "Alice", timestamp: Time.now,
        message_text: "It works.", clauses:,
        avg_tenor: 0.5, avg_modality: 0.5, dominant_mood: "declarative",
        process_types: {}, participants: [], tenor_shift: nil
      )
      with_turns = result.new(turns: [turn])

      json = JSON.parse(described_class.new(with_turns).render)
      coverage = json["metadata"]["annotation_coverage"]

      expect(coverage["total_clauses"]).to eq(4)
      expect(coverage["llm"]).to eq(2)
      expect(coverage["fallback"]).to eq(1)
      expect(coverage["stub"]).to eq(1)
      expect(coverage["defaulted_pct"]).to eq(50.0)
    end

    it "includes speaker profiles" do
      formatter = described_class.new(result)
      json = JSON.parse(formatter.render)

      expect(json["speaker_profiles"]["Alice"]["avg_tenor"]).to eq(0.38)
      expect(json["speaker_profiles"]["Alice"]["turn_count"]).to eq(3)
      expect(json["speaker_profiles"]["Alice"]["mood_distribution"]["declarative"]).to eq(0.72)
    end

    it "includes correlations" do
      formatter = described_class.new(result)
      json = JSON.parse(formatter.render)

      expect(json["correlations"]["mental"]["avg_tenor"]).to eq(0.34)
      expect(json["correlations"]["verbal"]["avg_modality"]).to eq(0.78)
    end

    it "includes insights" do
      formatter = described_class.new(result)
      json = JSON.parse(formatter.render)

      expect(json["insights"]).to include("Alice maintains casual tenor across conversation")
    end
  end

  describe "turns array" do
    def build_clause(annotation_source)
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
      SFL::Compiler::Types::AnnotatedClause.new(
        id: "ann-1", text: "It works.", syntactic:,
        ideational:,
        interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
          clause_id: "syn-1", mood: "declarative",
          modality_weight: 0.5, tenor: 0.5,
          speaker_attitude: nil, reasoning: nil,
          annotation_source:
        ),
        document_id: "doc-1", compiled_at: Time.now
      )
    end

    def build_turn(clauses:, message_text: "It works.")
      SFL::Compiler::Types::ConversationTurn.new(
        turn_id: 1, speaker: "Alice", timestamp: Time.parse("2026-06-10 14:32:15"),
        message_text:, clauses:,
        avg_tenor: 0.5, avg_modality: 0.5, dominant_mood: "declarative",
        process_types: {}, participants: [], tenor_shift: nil
      )
    end

    let(:mixed_sources_result) do
      result.new(turns: [build_turn(clauses: %w[llm fallback stub].map { |s| build_clause(s) })])
    end

    let(:empty_clauses_result) do
      result.new(turns: [build_turn(clauses: [])])
    end

    it "emits one row per turn with preview and provenance counts" do
      with_turns = result.new(turns: [build_turn(clauses: [build_clause("llm")], message_text: "x" * 250)])
      parsed = JSON.parse(described_class.new(with_turns).render)
      rows = parsed["turns"]

      expect(rows.size).to eq(with_turns.turns.size)
      row = rows.first
      expect(row.keys).to include(
        "turn_id", "speaker", "timestamp", "preview", "avg_tenor",
        "avg_modality", "dominant_mood", "tenor_shift",
        "clause_count", "defaulted_count"
      )
      expect(row["preview"].length).to be <= 200
    end

    it "counts fallback and stub clauses as defaulted, llm as not" do
      parsed = JSON.parse(described_class.new(mixed_sources_result).render)
      expect(parsed["turns"].first["defaulted_count"]).to eq(2)
      expect(parsed["turns"].first["clause_count"]).to eq(3)
    end

    it "handles a turn with zero clauses" do
      parsed = JSON.parse(described_class.new(empty_clauses_result).render)
      expect(parsed["turns"].first["clause_count"]).to eq(0)
      expect(parsed["turns"].first["defaulted_count"]).to eq(0)
      expect(parsed["turns"].first["clauses"]).to eq([])
    end
  end

  describe "reasoning_trace serialization" do
    def reasoning_trace
      SFL::Compiler::Types::ReasoningTrace.new(
        premises: [
          SFL::Compiler::Types::Premise.new(type: "token", source: "unanimously", value: "ADV", weight: 0.7),
          SFL::Compiler::Types::Premise.new(type: "discourse_marker", source: "however", value: "ADV", weight: nil),
        ],
        inference_rule: "tenor_high_formal_register",
        conclusion: { tenor: 0.8 },
        confidence: 0.92,
        derivation_hash: "a3f2b7c",
        generated_at: Time.parse("2026-06-10 14:32:15")
      )
    end

    def build_clause(annotation_source, reasoning_trace: nil)
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
      SFL::Compiler::Types::AnnotatedClause.new(
        id: "ann-#{annotation_source}", text: "It works.", syntactic:,
        ideational:,
        interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
          clause_id: "syn-1", mood: "declarative",
          modality_weight: 0.5, tenor: 0.5,
          speaker_attitude: nil, reasoning: nil,
          annotation_source:, reasoning_trace:
        ),
        document_id: "doc-1", compiled_at: Time.now
      )
    end

    def build_turn(clauses)
      SFL::Compiler::Types::ConversationTurn.new(
        turn_id: 1, speaker: "Alice", timestamp: Time.parse("2026-06-10 14:32:15"),
        message_text: "It works.", clauses:,
        avg_tenor: 0.5, avg_modality: 0.5, dominant_mood: "declarative",
        process_types: {}, participants: [], tenor_shift: nil
      )
    end

    it "serializes a populated reasoning_trace with ISO8601 generated_at and plain-hash premises" do
      llm_clause = build_clause("llm", reasoning_trace:)
      with_turns = result.new(turns: [build_turn([llm_clause])])

      expect { described_class.new(with_turns).render }.not_to raise_error
      parsed = JSON.parse(described_class.new(with_turns).render)
      clause_row = parsed["turns"].first["clauses"].first

      expect(clause_row["id"]).to eq("ann-llm")
      expect(clause_row["annotation_source"]).to eq("llm")

      trace = clause_row["reasoning_trace"]
      expect(trace["inference_rule"]).to eq("tenor_high_formal_register")
      expect(trace["derivation_hash"]).to eq("a3f2b7c")
      expect(trace["generated_at"]).to eq(Time.parse("2026-06-10 14:32:15").iso8601)
      expect(trace["premises"]).to eq([
        { "type" => "token", "source" => "unanimously", "value" => "ADV", "weight" => 0.7 },
        { "type" => "discourse_marker", "source" => "however", "value" => "ADV", "weight" => nil },
      ])
    end

    it "serializes nil reasoning_trace as null for a fallback-sourced clause" do
      fallback_clause = build_clause("fallback")
      with_turns = result.new(turns: [build_turn([fallback_clause])])
      parsed = JSON.parse(described_class.new(with_turns).render)

      expect(parsed["turns"].first["clauses"].first["reasoning_trace"]).to be_nil
    end
  end
end
