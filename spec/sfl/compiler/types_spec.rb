# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Types do
  describe "SyntacticToken" do
    it "creates a token with all attributes" do
      token = SFL::Compiler::Types::SyntacticToken.new(
        text: "running",
        lemma: "run",
        pos: "VERB",
        tag: "VBG",
        dep: "ROOT",
        head_index: -1,
        morphology: { "Tense" => "Pres", "VerbForm" => "Part" },
        index: 0
      )

      expect(token.text).to eq("running")
      expect(token.pos).to eq("VERB")
      expect(token.dep).to eq("ROOT")
    end
  end

  describe "SyntacticClause" do
    it "creates a clause with tokens" do
      token = SFL::Compiler::Types::SyntacticToken.new(
        text: "test", lemma: "test", pos: "NOUN", tag: "NN",
        dep: "ROOT", head_index: -1, morphology: {}, index: 0
      )

      clause = SFL::Compiler::Types::SyntacticClause.new(
        id: "test-1",
        text: "This is a test.",
        tokens: [token],
        root_index: 0,
        sentence_index: 0,
        document_id: "doc-1"
      )

      expect(clause.text).to eq("This is a test.")
      expect(clause.tokens.length).to eq(1)
      expect(clause.document_id).to eq("doc-1")
    end
  end

  describe "IdeationalPayload" do
    it "creates an ideational payload" do
      actor = SFL::Compiler::Types::Participant.new(role: "Actor", text: "system")
      goal = SFL::Compiler::Types::Participant.new(role: "Goal", text: "data")

      payload = SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "c-1",
        process_type: "material",
        participants: [actor, goal],
        circumstances: ["prep:in database"],
        raw_transitivity: { root: { text: "process" } }
      )

      expect(payload.process_type).to eq("material")
      expect(payload.participants.first.role).to eq("Actor")
      expect(payload.participants.first.text).to eq("system")
    end

    it "rejects invalid process types" do
      expect do
        SFL::Compiler::Types::IdeationalPayload.new(
          clause_id: "c-1",
          process_type: "invalid",
          participants: [],
          circumstances: [],
          raw_transitivity: {}
        )
      end.to raise_error(Dry::Struct::Error)
    end
  end

  describe "InterpersonalPayload" do
    it "creates an interpersonal payload" do
      payload = SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "c-1",
        mood: "declarative",
        modality_weight: 0.8,
        tenor: 0.6,
        speaker_attitude: "assertive",
        reasoning: "High certainty verb with formal register"
      )

      expect(payload.mood).to eq("declarative")
      expect(payload.modality_weight).to eq(0.8)
      expect(payload.tenor).to eq(0.6)
    end

    it "rejects modality_weight outside 0.0-1.0" do
      expect do
        SFL::Compiler::Types::InterpersonalPayload.new(
          clause_id: "c-1",
          mood: "declarative",
          modality_weight: 1.5,
          tenor: 0.5,
          speaker_attitude: nil,
          reasoning: nil
        )
      end.to raise_error(Dry::Struct::Error)
    end

    describe "annotation_source provenance" do
      def payload(**overrides)
        SFL::Compiler::Types::InterpersonalPayload.new(
          {
            clause_id: "c-1",
            mood: "declarative",
            modality_weight: 0.5,
            tenor: 0.5,
            speaker_attitude: nil,
            reasoning: nil,
          }.merge(overrides)
        )
      end

      it "defaults annotation_source to llm" do
        expect(payload.annotation_source).to eq("llm")
      end

      it "accepts fallback and stub sources" do
        expect(payload(annotation_source: "fallback").annotation_source).to eq("fallback")
        expect(payload(annotation_source: "stub").annotation_source).to eq("stub")
      end

      it "rejects unknown annotation sources" do
        expect { payload(annotation_source: "guess") }.to raise_error(Dry::Struct::Error)
      end
    end
  end

  describe "TextualPayload" do
    it "creates a textual payload with valid theme_type values" do
      payload = SFL::Compiler::Types::TextualPayload.new(
        clause_id: "c-1",
        topical_theme: "The system",
        textual_theme: "However",
        interpersonal_theme: "Surely",
        rheme: "processes data",
        theme_type: "unmarked"
      )

      expect(payload.clause_id).to eq("c-1")
      expect(payload.topical_theme).to eq("The system")
      expect(payload.theme_type).to eq("unmarked")
    end

    it "accepts all valid theme_type enum values" do
      valid_types = %w[
        unmarked
        marked
        interrogative
        imperative
        multiple
        topical
        simple
        existential
        clausal
        textual
        interjection
        interpersonal
      ]

      valid_types.each do |theme_type|
        payload = SFL::Compiler::Types::TextualPayload.new(
          clause_id: "c-1",
          theme_type:,
          topical_theme: "Test",
          textual_theme: nil,
          interpersonal_theme: nil,
          rheme: nil
        )
        expect(payload.theme_type).to eq(theme_type)
      end
    end

    it "rejects invalid theme_type values" do
      expect do
        SFL::Compiler::Types::TextualPayload.new(
          clause_id: "c-1",
          theme_type: "invalid_type",
          topical_theme: "Test",
          textual_theme: nil,
          interpersonal_theme: nil,
          rheme: nil
        )
      end.to raise_error(Dry::Struct::Error)
    end

    it "accepts nil for optional theme_type" do
      payload = SFL::Compiler::Types::TextualPayload.new(
        clause_id: "c-1",
        theme_type: nil,
        topical_theme: "Test",
        textual_theme: nil,
        interpersonal_theme: nil,
        rheme: nil
      )
      expect(payload.theme_type).to be_nil
    end
  end

  describe "AnnotatedClause" do
    it "creates a fully annotated clause" do
      token = SFL::Compiler::Types::SyntacticToken.new(
        text: "test", lemma: "test", pos: "NOUN", tag: "NN",
        dep: "ROOT", head_index: -1, morphology: {}, index: 0
      )
      clause = SFL::Compiler::Types::SyntacticClause.new(
        id: "syn-1", text: "Test.", tokens: [token],
        root_index: 0, sentence_index: 0, document_id: "doc-1"
      )
      ideational = SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "syn-1", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      )
      interpersonal = SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "syn-1", mood: "declarative",
        modality_weight: 0.5, tenor: 0.5,
        speaker_attitude: nil, reasoning: nil
      )

      annotated = SFL::Compiler::Types::AnnotatedClause.new(
        id: "ann-1",
        text: "Test.",
        syntactic: clause,
        ideational:,
        interpersonal:,
        document_id: "doc-1",
        compiled_at: Time.now
      )

      expect(annotated.id).to eq("ann-1")
      expect(annotated.ideational.process_type).to eq("material")
      expect(annotated.interpersonal.mood).to eq("declarative")
    end
  end

  describe "ConversationTurn" do
    it "creates a valid conversation turn" do
      turn = SFL::Compiler::Types::ConversationTurn.new(
        turn_id: 1,
        speaker: "Alice",
        timestamp: Time.now,
        message_text: "Hello world",
        clauses: [],
        avg_tenor: 0.5,
        avg_modality: 0.6,
        dominant_mood: "declarative",
        process_types: { "mental" => 2, "material" => 1 },
        participants: %w[Alice world],
        tenor_shift: 0.0
      )

      expect(turn.turn_id).to eq(1)
      expect(turn.speaker).to eq("Alice")
      expect(turn.avg_tenor).to eq(0.5)
    end

    it "requires all mandatory fields" do
      expect do
        SFL::Compiler::Types::ConversationTurn.new(turn_id: 1)
      end.to raise_error(Dry::Struct::Error)
    end
  end

  describe "SpeakerProfile" do
    it "creates a valid speaker profile" do
      profile = SFL::Compiler::Types::SpeakerProfile.new(
        speaker_name: "Alice",
        turn_count: 5,
        avg_tenor: 0.45,
        tenor_range: [0.2, 0.7],
        tenor_variance: 0.12,
        avg_modality: 0.52,
        mood_distribution: { "declarative" => 0.8, "interrogative" => 0.2 },
        dominant_processes: { "mental" => 10, "material" => 5 }
      )

      expect(profile.speaker_name).to eq("Alice")
      expect(profile.turn_count).to eq(5)
      expect(profile.tenor_range).to eq([0.2, 0.7])
    end

    it "requires all mandatory fields" do
      expect do
        SFL::Compiler::Types::SpeakerProfile.new(speaker_name: "Alice")
      end.to raise_error(Dry::Struct::Error)
    end
  end

  describe "AnalysisResult" do
    it "creates a valid analysis result" do
      result = SFL::Compiler::Types::AnalysisResult.new(
        metadata: { conversation_id: "test", turn_count: 5 },
        turns: [],
        speaker_profiles: {},
        tenor_timeline: [],
        field_evolution: [],
        correlations: {},
        insights: ["Sample insight"]
      )

      expect(result.metadata[:conversation_id]).to eq("test")
      expect(result.insights).to eq(["Sample insight"])
    end
  end

  describe "SynthesisResult" do
    it "creates a synthesis result" do
      result = SFL::Compiler::Types::SynthesisResult.new(
        query: "what is tenor?",
        answer: "Tenor is the formality dimension.",
        cited_clause_ids: ["c-1"],
        clauses: [{ clause_id: "c-1", text: "..." }],
        retrieved_count: 3,
        confidence: 0.8
      )
      expect(result.answer).to include("formality")
      expect(result.cited_clause_ids).to eq(["c-1"])
    end

    it "allows a nil answer for empty retrievals" do
      result = SFL::Compiler::Types::SynthesisResult.new(
        query: "anything", answer: nil, retrieved_count: 0, confidence: nil
      )
      expect(result.answer).to be_nil
      expect(result.clauses).to eq([])
    end
  end

  describe SFL::Compiler::Types::NarrativeReport do
    let(:sections) do
      {
        overview: "o",
        cast_and_roles: "c",
        interpersonal_dynamics: "i",
        conversational_arc: "a",
        data_quality: "d",
        takeaways: "t",
      }
    end

    it "holds source, generated_at, and six prose sections" do
      report = described_class.new(
        source: "conv-1", generated_at: Time.now, **sections
      )
      expect(report.overview).to eq("o")
      expect(report.takeaways).to eq("t")
    end

    it "rejects a missing section" do
      expect do
        described_class.new(source: "conv-1", generated_at: Time.now,
                            **sections.except(:takeaways))
      end.to raise_error(Dry::Struct::Error)
    end
  end
end

describe "Gush payload round-trip (Types.dump / Types.load_conversation_turn)" do
  let(:token) do
    SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
  end

  let(:annotated_clause) do
    syntactic = SFL::Compiler::Types::SyntacticClause.new(
      id: "syn-1", text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: "turn-1"
    )
    SFL::Compiler::Types::AnnotatedClause.new(
      id: "ann-1", text: "It works.", syntactic:,
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "syn-1", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "syn-1", mood: "declarative",
        modality_weight: 0.6, tenor: 0.7,
        speaker_attitude: nil, reasoning: nil, annotation_source: "llm"
      ),
      document_id: "turn-1", compiled_at: Time.now
    )
  end

  let(:turn) do
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: 1, speaker: "Alice", timestamp: Time.now,
      message_text: "It works.", clauses: [annotated_clause],
      avg_tenor: 0.7, avg_modality: 0.6, dominant_mood: "declarative",
      process_types: { "material" => 1 }, participants: [], tenor_shift: nil
    )
  end

  it "survives a real JSON round trip with the same field values" do
    json = JSON.generate(SFL::Compiler::Types.dump(turn))
    hash = JSON.parse(json, symbolize_names: true)
    reloaded = SFL::Compiler::Types.load_conversation_turn(hash)

    expect(reloaded.turn_id).to eq(turn.turn_id)
    expect(reloaded.speaker).to eq(turn.speaker)
    expect(reloaded.timestamp.to_i).to eq(turn.timestamp.to_i)
    expect(reloaded.avg_tenor).to eq(turn.avg_tenor)
    expect(reloaded.clauses.size).to eq(1)
    expect(reloaded.clauses.first.id).to eq(annotated_clause.id)
    expect(reloaded.clauses.first.compiled_at.to_i).to eq(annotated_clause.compiled_at.to_i)
    expect(reloaded.clauses.first.syntactic.tokens.first.text).to eq("works")
  end
end

RSpec.describe "SFL::Compiler::NarrativeError" do
  it "is an SFL::Compiler::Error" do
    expect(SFL::Compiler::NarrativeError.ancestors).to include(SFL::Compiler::Error)
  end
end
