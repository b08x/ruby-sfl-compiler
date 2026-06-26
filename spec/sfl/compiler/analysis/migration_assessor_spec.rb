# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::MigrationAssessor do
  subject(:assessor) { described_class.new }

  def assess(content_type:, quality_score:)
    assessor.assess(
      artifact_id:   1,
      title:         "Test Artifact",
      source_file:   "notes/test.md",
      content_type:,
      quality_score:
    )
  end

  it "returns a Types::MigrationManifestEntry" do
    entry = assess(content_type: :research_note, quality_score: 0.6)
    expect(entry).to be_a(SFL::Compiler::Types::MigrationManifestEntry)
  end

  it "populates all required fields" do
    entry = assess(content_type: :tutorial, quality_score: 0.8)
    expect(entry.artifact_id).to eq(1)
    expect(entry.title).to eq("Test Artifact")
    expect(entry.source_file).to eq("notes/test.md")
    expect(entry.quality_score).to eq(0.8)
    expect(entry.content_type).to eq(:tutorial)
    expect(entry.reason).not_to be_empty
  end

  describe "review decisions for ground-truth types" do
    it "sends :ai_generated to review regardless of quality (verify before discarding)" do
      expect(assess(content_type: :ai_generated, quality_score: 0.95).action).to eq(:review)
      expect(assess(content_type: :ai_generated, quality_score: 0.10).action).to eq(:review)
    end
  end

  describe "archive decisions" do

    it "archives any type with quality below 0.35" do
      expect(assess(content_type: :research_note, quality_score: 0.30).action).to eq(:archive)
      expect(assess(content_type: :research_note, quality_score: 0.00).action).to eq(:archive)
    end

    it "archives low-quality content types that aren't in keep/review buckets" do
      expect(assess(content_type: :unknown, quality_score: 0.40).action).to eq(:archive)
    end
  end

  describe "review decisions" do
    it "sends :draft to review" do
      expect(assess(content_type: :draft, quality_score: 0.9).action).to eq(:review)
    end

    it "sends :code_snippet to review" do
      expect(assess(content_type: :code_snippet, quality_score: 0.8).action).to eq(:review)
    end

    it "sends :image to review" do
      expect(assess(content_type: :image, quality_score: 0.7).action).to eq(:review)
    end

    it "review types bypass the low-quality archive threshold" do
      expect(assess(content_type: :draft, quality_score: 0.10).action).to eq(:review)
    end
  end

  describe "keep decisions" do
    it "keeps high-quality :technical_reference (>= 0.65)" do
      expect(assess(content_type: :technical_reference, quality_score: 0.65).action).to eq(:keep)
      expect(assess(content_type: :technical_reference, quality_score: 0.90).action).to eq(:keep)
    end

    it "keeps high-quality :tutorial (>= 0.65)" do
      expect(assess(content_type: :tutorial, quality_score: 0.70).action).to eq(:keep)
    end

    it "does not keep :technical_reference below the keep threshold" do
      expect(assess(content_type: :technical_reference, quality_score: 0.60).action).not_to eq(:keep)
    end

    it "does not keep :research_note even at high quality" do
      expect(assess(content_type: :research_note, quality_score: 0.90).action).not_to eq(:keep)
    end
  end

  describe "update decisions" do
    it "recommends :update for adequate quality non-keep types (>= 0.50)" do
      expect(assess(content_type: :research_note, quality_score: 0.55).action).to eq(:update)
      expect(assess(content_type: :research_note, quality_score: 0.50).action).to eq(:update)
    end

    it "recommends :update for a keep-type just below the keep threshold" do
      expect(assess(content_type: :technical_reference, quality_score: 0.60).action).to eq(:update)
    end
  end

  describe "reason messages" do
    it "includes a recognisable description in the :ai_generated reason string" do
      entry = assess(content_type: :ai_generated, quality_score: 0.9)
      expect(entry.reason).to include("AI-generated").or include("ground truth")
    end

    it "includes the quality score in keep/update/archive reason strings" do
      entry = assess(content_type: :research_note, quality_score: 0.55)
      expect(entry.reason).to include("0.55")
    end
  end
end
