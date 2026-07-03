# frozen_string_literal: true

require "spec_helper"
require "sfl-compiler"

RSpec.describe SFL::Compiler::TUI::EvidencePane do
  def strip_ansi(str)
    str.gsub(/\e\[[0-9;]*m/, "")
  end

  def clause(text:, source:, trace: nil)
    {
      text:,
      interpersonal: {
        annotation_source: source,
        mood: "declarative",
        modality_weight: 0.5,
        tenor: 0.5,
        reasoning_trace: trace,
      },
    }
  end

  def trace(rule: "finite_precedes_subject", confidence: 0.9)
    {
      premises: [{ type: "token", source: "spacy", value: "is", weight: 1.0 }],
      inference_rule: rule,
      conclusion: { mood: "declarative" },
      confidence:,
      derivation_hash: "abc123",
      generated_at: Time.now.iso8601,
    }
  end

  def result_with(clauses)
    { turns: [{ clauses: }] }
  end

  describe "#render" do
    it "explains itself when the payload has no turn data (older reduce output)" do
      output = strip_ansi(described_class.new({ metadata: {} }, width: 100).render)

      expect(output).to include("no clause data in payload")
    end

    it "renders clause count and per-source legend counts" do
      pane = described_class.new(
        result_with([
          clause(text: "The system compiles clauses.", source: "llm"),
          clause(text: "It stores embeddings.", source: "llm"),
          clause(text: "Something ambiguous.", source: "fallback"),
        ]),
        width: 100
      )
      output = strip_ansi(pane.render)

      expect(output).to include("3 clauses")
      expect(output).to include("llm 2")
      expect(output).to include("fallback 1")
      expect(output).not_to include("stub")
    end

    it "lists non-llm clauses under Needs attention with their source tag" do
      pane = described_class.new(
        result_with([
          clause(text: "Fine clause.", source: "llm"),
          clause(text: "Defaulted clause text here.", source: "fallback"),
          clause(text: "Pass-one-only stub clause.", source: "stub"),
        ]),
        width: 100
      )
      output = strip_ansi(pane.render)

      expect(output).to include("Needs attention")
      expect(output).to include("2 non-llm clauses")
      expect(output).to include("[fallback] Defaulted clause text here.")
      expect(output).to include("[stub] Pass-one-only stub clause.")
    end

    it "omits the Needs attention section when every clause is llm-annotated" do
      pane = described_class.new(
        result_with([clause(text: "All good.", source: "llm")]),
        width: 100
      )

      expect(strip_ansi(pane.render)).not_to include("Needs attention")
    end

    it "does not flag human-reviewed clauses as needing attention" do
      pane = described_class.new(
        result_with([
          clause(text: "Reviewed by a human.", source: "human"),
          clause(text: "Still flagged.", source: "fallback"),
        ]),
        width: 100
      )
      output = strip_ansi(pane.render)

      expect(output).to include("1 non-llm clauses")
      expect(output).not_to include("Reviewed by a human.")
      expect(output).to include("[fallback] Still flagged.")
    end

    it "caps the flagged list and reports the overflow count" do
      flagged = Array.new(9) { |i| clause(text: "Bad clause #{i}", source: "fallback") }
      output = strip_ansi(described_class.new(result_with(flagged), width: 100).render)

      expect(output).to include("Bad clause 5")
      expect(output).not_to include("Bad clause 6")
      expect(output).to include("… 3 more")
    end

    it "summarizes reasoning traces: coverage, avg confidence, top inference rules" do
      pane = described_class.new(
        result_with([
          clause(text: "Traced one.", source: "llm", trace: trace(rule: "mood_from_finite", confidence: 0.8)),
          clause(text: "Traced two.", source: "llm", trace: trace(rule: "mood_from_finite", confidence: 1.0)),
          clause(text: "Untraced.", source: "llm"),
        ]),
        width: 100
      )
      output = strip_ansi(pane.render)

      expect(output).to include("Reasoning traces")
      expect(output).to include("2/3 clauses traced")
      expect(output).to include("avg confidence 0.90")
      expect(output).to include("mood_from_finite ×2")
    end

    it "notes the absence of reasoning traces instead of rendering an empty section" do
      pane = described_class.new(
        result_with([clause(text: "No trace.", source: "llm")]),
        width: 100
      )

      expect(strip_ansi(pane.render)).to include("no reasoning traces in this run")
    end

    it "truncates long clause text to the pane width" do
      long_text = "word " * 60
      pane = described_class.new(
        result_with([clause(text: long_text, source: "fallback")]),
        width: 80
      )
      output = strip_ansi(pane.render)

      expect(output).to include("…")
      expect(output).not_to include(long_text.strip)
    end
  end
end
