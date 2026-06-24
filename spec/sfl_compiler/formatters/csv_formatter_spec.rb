require "spec_helper"
require "csv"

RSpec.describe SFL::Compiler::Formatters::CSVFormatter do
  let(:turn1) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 1,
      speaker: "Alice",
      timestamp: Time.parse("2026-06-10 14:30:00"),
      message_text: "Hello there, how are you doing today?",
      clauses: [],
      avg_tenor: 0.32,
      avg_modality: 0.45,
      dominant_mood: "declarative",
      process_types: { "mental" => 1, "relational" => 1 },
      participants: ["I", "you"],
      tenor_shift: nil,
      semantic_coherence_score: 0.85
    )
  end

  let(:turn2) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 2,
      speaker: "Bob",
      timestamp: Time.parse("2026-06-10 14:31:00"),
      message_text: "I'm doing great, thanks!",
      clauses: [],
      avg_tenor: 0.28,
      avg_modality: 0.82,
      dominant_mood: "declarative",
      process_types: { "material" => 1 },
      participants: ["I"],
      tenor_shift: -0.04,
      semantic_coherence_score: 0.92
    )
  end

  let(:result) do
    SFL::Compiler::Types::AnalysisResult.new(
      metadata: { conversation_id: "test" },
      turns: [turn1, turn2],
      speaker_profiles: {},
      tenor_timeline: [],
      field_evolution: [],
      correlations: {},
      insights: []
    )
  end

  describe "#render" do
    it "generates CSV with correct headers" do
      formatter = described_class.new(result)
      csv_output = formatter.render

      csv = CSV.parse(csv_output, headers: true)
      expect(csv.headers).to eq([
        "turn_id", "speaker", "timestamp", "message_preview",
        "avg_tenor", "avg_modality", "dominant_mood",
        "process_counts", "participants", "tenor_shift", "semantic_coherence_score"
      ])
    end

    it "includes turn data rows" do
      formatter = described_class.new(result)
      csv_output = formatter.render

      csv = CSV.parse(csv_output, headers: true)
      expect(csv.count).to eq(2)

      row1 = csv[0]
      expect(row1["turn_id"]).to eq("1")
      expect(row1["speaker"]).to eq("Alice")
      expect(row1["avg_tenor"]).to eq("0.32")
      expect(row1["avg_modality"]).to eq("0.45")
      expect(row1["dominant_mood"]).to eq("declarative")
      expect(row1["process_counts"]).to eq("mental:1 relational:1")
      expect(row1["participants"]).to eq("I you")
      expect(row1["tenor_shift"]).to eq("")
      expect(row1["semantic_coherence_score"]).to eq("0.85")
    end

    it "truncates long messages" do
      formatter = described_class.new(result)
      csv_output = formatter.render

      csv = CSV.parse(csv_output, headers: true)
      row1 = csv[0]
      expect(row1["message_preview"].length).to be <= 53 # includes "..."
    end
  end
end
