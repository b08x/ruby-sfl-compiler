require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::SpeakerProfiler do
  let(:alice_turns) do
    [
      build_turn(speaker: "Alice", avg_tenor: 0.3, avg_modality: 0.4, mood: "declarative", process: "mental"),
      build_turn(speaker: "Alice", avg_tenor: 0.5, avg_modality: 0.6, mood: "declarative", process: "mental"),
      build_turn(speaker: "Alice", avg_tenor: 0.4, avg_modality: 0.5, mood: "interrogative", process: "material")
    ]
  end

  let(:bob_turns) do
    [
      build_turn(speaker: "Bob", avg_tenor: 0.7, avg_modality: 0.8, mood: "declarative", process: "verbal"),
      build_turn(speaker: "Bob", avg_tenor: 0.75, avg_modality: 0.82, mood: "exclamative", process: "verbal")
    ]
  end

  def build_turn(speaker:, avg_tenor:, avg_modality:, mood:, process:)
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: rand(1..100),
      speaker: speaker,
      timestamp: Time.now,
      message_text: "Test",
      clauses: [],
      avg_tenor: avg_tenor,
      avg_modality: avg_modality,
      dominant_mood: mood,
      process_types: { process => 1 },
      participants: [],
      tenor_shift: nil
    )
  end

  describe "#build_profile" do
    it "builds speaker profile from turns" do
      profiler = described_class.new(alice_turns)
      profile = profiler.build_profile

      expect(profile.speaker_name).to eq("Alice")
      expect(profile.turn_count).to eq(3)
      expect(profile.avg_tenor).to be_within(0.01).of(0.4)
      expect(profile.tenor_range).to eq([0.3, 0.5])
      expect(profile.tenor_variance).to be > 0
      expect(profile.avg_modality).to be_within(0.01).of(0.5)
    end

    it "calculates mood distribution" do
      profiler = described_class.new(alice_turns)
      profile = profiler.build_profile

      expect(profile.mood_distribution["declarative"]).to be_within(0.01).of(0.67)
      expect(profile.mood_distribution["interrogative"]).to be_within(0.01).of(0.33)
    end

    it "aggregates process types" do
      profiler = described_class.new(alice_turns)
      profile = profiler.build_profile

      expect(profile.dominant_processes["mental"]).to eq(2)
      expect(profile.dominant_processes["material"]).to eq(1)
    end
  end

  describe ".build_profiles" do
    it "builds profiles for all speakers" do
      all_turns = alice_turns + bob_turns
      profiles = described_class.build_profiles(all_turns)

      expect(profiles.keys).to contain_exactly("Alice", "Bob")
      expect(profiles["Alice"].turn_count).to eq(3)
      expect(profiles["Bob"].turn_count).to eq(2)
      expect(profiles["Bob"].avg_tenor).to be > profiles["Alice"].avg_tenor
    end
  end
end
