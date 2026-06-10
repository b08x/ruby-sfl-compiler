# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::IdeationalExtractor do
  subject(:extractor) { described_class.new }

  describe "#extract" do
    it "classifies material processes" do
      token = SFL::Compiler::Types::SyntacticToken.new(
        text: "processes", lemma: "process", pos: "VERB", tag: "VBZ",
        dep: "ROOT", head_index: -1, morphology: {}, index: 0
      )
      clause = SFL::Compiler::Types::SyntacticClause.new(
        id: "c-1", text: "The system processes data.",
        tokens: [token], root_index: 0, sentence_index: 0, document_id: nil
      )

      result = extractor.extract(clause)
      expect(result.process_type).to eq("material")
    end

    it "classifies mental processes" do
      token = SFL::Compiler::Types::SyntacticToken.new(
        text: "knows", lemma: "know", pos: "VERB", tag: "VBZ",
        dep: "ROOT", head_index: -1, morphology: {}, index: 0
      )
      clause = SFL::Compiler::Types::SyntacticClause.new(
        id: "c-2", text: "The user knows the answer.",
        tokens: [token], root_index: 0, sentence_index: 0, document_id: nil
      )

      result = extractor.extract(clause)
      expect(result.process_type).to eq("mental")
    end

    it "classifies relational processes" do
      token = SFL::Compiler::Types::SyntacticToken.new(
        text: "is", lemma: "be", pos: "AUX", tag: "VBZ",
        dep: "ROOT", head_index: -1, morphology: {}, index: 0
      )
      clause = SFL::Compiler::Types::SyntacticClause.new(
        id: "c-3", text: "The result is correct.",
        tokens: [token], root_index: 0, sentence_index: 0, document_id: nil
      )

      result = extractor.extract(clause)
      expect(result.process_type).to eq("relational")
    end

    it "classifies behavioral processes" do
      token = SFL::Compiler::Types::SyntacticToken.new(
        text: "smiled", lemma: "smile", pos: "VERB", tag: "VBD",
        dep: "ROOT", head_index: -1, morphology: {}, index: 0
      )
      clause = SFL::Compiler::Types::SyntacticClause.new(
        id: "c-6", text: "The user smiled.",
        tokens: [token], root_index: 0, sentence_index: 0, document_id: nil
      )

      result = extractor.extract(clause)
      expect(result.process_type).to eq("behavioral")
    end

    it "extracts participants from dependency roles" do
      tokens = [
        SFL::Compiler::Types::SyntacticToken.new(
          text: "System", lemma: "system", pos: "NOUN", tag: "NN",
          dep: "nsubj", head_index: 1, morphology: {}, index: 0
        ),
        SFL::Compiler::Types::SyntacticToken.new(
          text: "processes", lemma: "process", pos: "VERB", tag: "VBZ",
          dep: "ROOT", head_index: -1, morphology: {}, index: 1
        ),
        SFL::Compiler::Types::SyntacticToken.new(
          text: "data", lemma: "data", pos: "NOUN", tag: "NNS",
          dep: "dobj", head_index: 1, morphology: {}, index: 2
        )
      ]
      clause = SFL::Compiler::Types::SyntacticClause.new(
        id: "c-4", text: "System processes data.",
        tokens: tokens, root_index: 1, sentence_index: 0, document_id: nil
      )

      result = extractor.extract(clause)
      expect(result.participants.map(&:role)).to include("Actor")
      expect(result.participants.map(&:text)).to include("System")
      expect(result.participants.map(&:role)).to include("Goal")
      expect(result.participants.map(&:text)).to include("data")
    end

    it "handles nil root token gracefully" do
      clause = SFL::Compiler::Types::SyntacticClause.new(
        id: "c-5", text: "", tokens: [], root_index: 0,
        sentence_index: 0, document_id: nil
      )

      result = extractor.extract(clause)
      expect(result.process_type).to eq("material")
      expect(result.participants).to be_empty
    end
  end
end
