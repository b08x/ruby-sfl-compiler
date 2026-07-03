# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Formatters::KBAnnotatedDocFormatter do
  def make_artifact(clauses:, section_path: "Introduction")
    SFL::Compiler::Types::KnowledgeArtifact.new(
      artifact_id: 1,
      title: "Test Doc",
      source_file: "/notes/test.md",
      section_path:,
      content_type: "technical_reference",
      quality_score: 0.75,
      migration_action: "keep",
      migration_reason: "High quality",
      clauses:,
      avg_tenor: 0.5,
      avg_modality: 0.6,
      dominant_mood: "declarative",
      process_types: {},
      annotation_coverage: {}
    )
  end

  it "tags each clause inline with process type, mood, tenor, and modality" do
    clause = make_clause(process_type: "material", mood: "declarative", tenor: 0.62, modality_weight: 0.81)
    artifact = make_artifact(clauses: [clause])

    output = described_class.new(artifact).render

    expect(output).to include(clause.text)
    expect(output).to include("material · declarative · tenor=0.62 · modality=0.81")
  end

  it "renders clauses in their original order" do
    first = make_clause.new(text: "First sentence.")
    second = make_clause.new(text: "Second sentence.")
    artifact = make_artifact(clauses: [first, second])

    output = described_class.new(artifact).render

    expect(output.index("First sentence.")).to be < output.index("Second sentence.")
  end

  it "uses the section heading when present" do
    artifact = make_artifact(clauses: [make_clause], section_path: "Getting Started")

    expect(described_class.new(artifact).render).to include("## Getting Started")
  end

  it "falls back to an artifact-numbered heading when there's no section" do
    artifact = make_artifact(clauses: [make_clause], section_path: nil)

    expect(described_class.new(artifact).render).to include("## Artifact 1")
  end

  it "flags non-LLM annotations with a warning marker and data quality note" do
    fallback_clause = make_clause(annotation_source: "fallback")
    artifact = make_artifact(clauses: [fallback_clause])

    output = described_class.new(artifact).render

    expect(output).to include("⚠️")
    expect(output).to include("1 of 1 clauses carry fallback/stub annotations")
  end

  it "does not flag human-reviewed clauses with a warning marker" do
    human_clause = make_clause(annotation_source: "human")
    artifact = make_artifact(clauses: [human_clause])

    output = described_class.new(artifact).render

    expect(output).not_to include("⚠️")
  end

  it "handles an artifact with no clauses" do
    artifact = make_artifact(clauses: [])

    expect(described_class.new(artifact).render).to include("_No clauses extracted._")
  end
end
