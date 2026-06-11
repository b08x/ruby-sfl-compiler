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
        speakers: ["Alice", "Bob"],
        analyzed_at: Time.parse("2026-06-10 14:32:15")
      },
      turns: [],
      speaker_profiles: { "Alice" => alice_profile },
      tenor_timeline: [
        { timestamp: Time.parse("2026-06-10 14:30"), tenor: 0.32, speaker: "Alice" }
      ],
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
      expect(json["metadata"]["speakers"]).to eq(["Alice", "Bob"])
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
end
