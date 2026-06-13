# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe SFL::Compiler::Analysis::NarrativeGenerator do
  def annotated_clause(source)
    token = SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
    syntactic = SFL::Compiler::Types::SyntacticClause.new(
      id: "syn-1", text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: "doc-1"
    )
    SFL::Compiler::Types::AnnotatedClause.new(
      id: SecureRandom.uuid, text: "It works.",
      syntactic: syntactic,
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "syn-1", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "syn-1", mood: "declarative", modality_weight: 0.7,
        tenor: 0.6, speaker_attitude: nil, reasoning: nil,
        annotation_source: source
      ),
      document_id: "doc-1", compiled_at: Time.now
    )
  end

  def turn(id, speaker, sources:, text: "Linearity isn't the enemy here.")
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: id, speaker: speaker, timestamp: Time.at(1_700_000_000 + id),
      message_text: text, clauses: sources.map { |s| annotated_clause(s) },
      avg_tenor: 0.6, avg_modality: 0.7, dominant_mood: "declarative",
      process_types: { "material" => 1 }, participants: [], tenor_shift: nil
    )
  end

  let(:result) do
    SFL::Compiler::Types::AnalysisResult.new(
      metadata: { conversation_id: "conv-1", turn_count: 2, speakers: %w[A B] },
      turns: [
        turn(1, "A", sources: %w[llm llm]),
        turn(2, "B", sources: %w[fallback fallback fallback llm])
      ],
      speaker_profiles: {},
      tenor_timeline: [], field_evolution: [],
      correlations: { "material" => { count: 6, avg_tenor: 0.6, avg_modality: 0.7 } },
      insights: ["A contributed 1 of 2 turns"]
    )
  end

  describe described_class::Digest do
    describe ".from_result" do
      it "includes per-turn previews and provenance counts in the text" do
        text = described_class.from_result(result).to_text
        expect(text).to include("Linearity isn't the enemy")
        expect(text).to include("conv-1")
      end

      it "marks turns with >50% defaulted clauses UNRELIABLE" do
        text = described_class.from_result(result).to_text
        expect(text).to match(/turn 2.*UNRELIABLE \(75% fallback\)/i)
        expect(text).not_to match(/turn 1.*UNRELIABLE/i)
      end
    end

    describe ".from_json" do
      it "produces identical text to from_result for the same analysis" do
        json = SFL::Compiler::Formatters::JSONFormatter.new(result).render
        from_json = described_class.from_json(JSON.parse(json)).to_text
        from_result = described_class.from_result(result).to_text
        expect(from_json).to eq(from_result)
      end

      it "stays equivalent with populated speaker profiles" do
        profile = SFL::Compiler::Types::SpeakerProfile.new(
          speaker_name: "A", turn_count: 1, avg_tenor: 0.6,
          tenor_range: [0.5, 0.7], tenor_variance: 0.01, avg_modality: 0.7,
          mood_distribution: { "declarative" => 1.0 },
          dominant_processes: { "material" => 2 }
        )
        with_profiles = result.new(speaker_profiles: { "A" => profile })

        json = SFL::Compiler::Formatters::JSONFormatter.new(with_profiles).render
        expect(described_class.from_json(JSON.parse(json)).to_text)
          .to eq(described_class.from_result(with_profiles).to_text)
      end

      it "raises NarrativeError when turns are absent" do
        expect {
          described_class.from_json({ "metadata" => {} })
        }.to raise_error(SFL::Compiler::NarrativeError, /turns.*re-run/i)
      end

      it "raises NarrativeError naming a missing turn key" do
        bad = { "metadata" => {}, "turns" => [{ "turn_id" => 1 }] }
        expect {
          described_class.from_json(bad)
        }.to raise_error(SFL::Compiler::NarrativeError, /speaker/)
      end
    end
  end
end
