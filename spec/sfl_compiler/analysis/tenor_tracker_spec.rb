require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::TenorTracker do
  let(:turn1) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 1,
      speaker: "Alice",
      timestamp: Time.now,
      message_text: "Hello",
      clauses: [],
      avg_tenor: 0.3,
      avg_modality: 0.5,
      dominant_mood: "declarative",
      process_types: {},
      participants: [],
      tenor_shift: nil
    )
  end

  let(:turn2) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 2,
      speaker: "Bob",
      timestamp: Time.now + 60,
      message_text: "Hi there",
      clauses: [],
      avg_tenor: 0.7,
      avg_modality: 0.6,
      dominant_mood: "declarative",
      process_types: {},
      participants: [],
      tenor_shift: nil
    )
  end

  let(:turn3) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 3,
      speaker: "Alice",
      timestamp: Time.now + 120,
      message_text: "Thanks",
      clauses: [],
      avg_tenor: 0.5,
      avg_modality: 0.55,
      dominant_mood: "declarative",
      process_types: {},
      participants: [],
      tenor_shift: nil
    )
  end

  describe "#calculate_shifts" do
    it "calculates tenor shifts between consecutive turns" do
      tracker = described_class.new([turn1, turn2, turn3])
      tracker.calculate_shifts

      expect(tracker.turns[0].tenor_shift).to be_nil
      expect(tracker.turns[1].tenor_shift).to be_within(0.0001).of(0.4)
      expect(tracker.turns[2].tenor_shift).to be_within(0.0001).of(-0.2)
    end
  end

  describe "#detect_significant_shifts" do
    it "finds shifts above threshold" do
      tracker = described_class.new([turn1, turn2, turn3], threshold: 0.15)
      tracker.calculate_shifts
      shifts = tracker.detect_significant_shifts

      expect(shifts.count).to eq(2)
      expect(shifts.first[:turn_id]).to eq(2)
      expect(shifts.first[:delta]).to be_within(0.0001).of(0.4)
      expect(shifts.first[:direction]).to eq("more formal")

      expect(shifts.last[:turn_id]).to eq(3)
      expect(shifts.last[:delta]).to be_within(0.0001).of(-0.2)
      expect(shifts.last[:direction]).to eq("less formal")
    end

    it "ignores shifts below threshold" do
      tracker = described_class.new([turn1, turn2, turn3], threshold: 0.5)
      tracker.calculate_shifts
      shifts = tracker.detect_significant_shifts

      expect(shifts).to be_empty
    end
  end
end
