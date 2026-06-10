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
      expect {
        SFL::Compiler::Types::IdeationalPayload.new(
          clause_id: "c-1",
          process_type: "invalid",
          participants: [],
          circumstances: [],
          raw_transitivity: {}
        )
      }.to raise_error(Dry::Struct::Error)
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
      expect {
        SFL::Compiler::Types::InterpersonalPayload.new(
          clause_id: "c-1",
          mood: "declarative",
          modality_weight: 1.5,
          tenor: 0.5,
          speaker_attitude: nil,
          reasoning: nil
        )
      }.to raise_error(Dry::Struct::Error)
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
        ideational: ideational,
        interpersonal: interpersonal,
        document_id: "doc-1",
        compiled_at: Time.now
      )

      expect(annotated.id).to eq("ann-1")
      expect(annotated.ideational.process_type).to eq("material")
      expect(annotated.interpersonal.mood).to eq("declarative")
    end
  end
end
