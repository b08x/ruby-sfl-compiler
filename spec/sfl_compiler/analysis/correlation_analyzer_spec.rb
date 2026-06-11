require "spec_helper"
require "securerandom"

RSpec.describe SFL::Compiler::Analysis::CorrelationAnalyzer do
  let(:turns) do
    [
      build_turn_with_clauses("mental", tenor: 0.3, modality: 0.4),
      build_turn_with_clauses("mental", tenor: 0.35, modality: 0.42),
      build_turn_with_clauses("verbal", tenor: 0.7, modality: 0.8),
      build_turn_with_clauses("verbal", tenor: 0.75, modality: 0.82),
      build_turn_with_clauses("material", tenor: 0.5, modality: 0.6)
    ]
  end

  def build_turn_with_clauses(process_type, tenor:, modality:)
    clause = SFL::Compiler::Types::AnnotatedClause.new(
      id: SecureRandom.uuid,
      text: "Test clause",
      syntactic: SFL::Compiler::Types::SyntacticClause.new(
        text: "Test clause",
        tokens: [],
        root_index: 0,
        sentence_index: 0,
        document_id: "test-doc"
      ),
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: SecureRandom.uuid,
        process_type: process_type,
        participants: [],
        circumstances: [],
        raw_transitivity: {}
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: SecureRandom.uuid,
        mood: "declarative",
        modality_weight: modality,
        tenor: tenor,
        speaker_attitude: nil,
        reasoning: nil
      ),
      document_id: "test-doc",
      compiled_at: Time.now
    )

    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: rand(1..100),
      speaker: "Test",
      timestamp: Time.now,
      message_text: "Test",
      clauses: [clause],
      avg_tenor: tenor,
      avg_modality: modality,
      dominant_mood: "declarative",
      process_types: { process_type => 1 },
      participants: [],
      tenor_shift: nil
    )
  end

  describe "#correlate_process_tenor" do
    it "calculates avg tenor per process type" do
      analyzer = described_class.new(turns)
      correlations = analyzer.correlate_process_tenor

      expect(correlations["mental"][:avg_tenor]).to be_within(0.01).of(0.325)
      expect(correlations["verbal"][:avg_tenor]).to be_within(0.01).of(0.725)
      expect(correlations["material"][:avg_tenor]).to eq(0.5)
    end

    it "calculates avg modality per process type" do
      analyzer = described_class.new(turns)
      correlations = analyzer.correlate_process_tenor

      expect(correlations["mental"][:avg_modality]).to be_within(0.01).of(0.41)
      expect(correlations["verbal"][:avg_modality]).to be_within(0.01).of(0.81)
    end

    it "includes clause counts" do
      analyzer = described_class.new(turns)
      correlations = analyzer.correlate_process_tenor

      expect(correlations["mental"][:count]).to eq(2)
      expect(correlations["verbal"][:count]).to eq(2)
      expect(correlations["material"][:count]).to eq(1)
    end
  end
end
