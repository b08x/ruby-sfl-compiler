require "spec_helper"

RSpec.describe SFL::Compiler::Formatters::MarkdownFormatter do
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
      tenor_timeline: [],
      field_evolution: [],
      correlations: {
        "mental" => { avg_tenor: 0.34, avg_modality: 0.41, count: 10 },
        "verbal" => { avg_tenor: 0.71, avg_modality: 0.78, count: 8 }
      },
      insights: [
        "Alice maintains casual tenor (0.38) throughout conversation",
        "Mental processes correlate with casual tenor (0.34)"
      ]
    )
  end

  describe "#render" do
    it "generates markdown document" do
      formatter = described_class.new(result)
      md = formatter.render

      expect(md).to include("# Conversation Analysis:")
      expect(md).to include("## Summary")
      expect(md).to include("## Speaker Profiles")
    end

    it "includes metadata in summary" do
      formatter = described_class.new(result)
      md = formatter.render

      expect(md).to include("**Turns**: 5")
      expect(md).to include("**Speakers**: Alice, Bob")
    end

    it "includes speaker profile table" do
      formatter = described_class.new(result)
      md = formatter.render

      expect(md).to include("| Alice")
      expect(md).to include("0.38")
      expect(md).to include("[0.22, 0.61]")
    end

    it "includes correlations table" do
      formatter = described_class.new(result)
      md = formatter.render

      expect(md).to include("## Tenor ↔ Field Correlations")
      expect(md).to include("| mental")
      expect(md).to include("0.34")
      expect(md).to include("0.41")
    end

    it "includes insights section" do
      formatter = described_class.new(result)
      md = formatter.render

      expect(md).to include("## Generated Insights")
      expect(md).to include("Alice maintains casual tenor")
      expect(md).to include("Mental processes correlate")
    end
  end
end
