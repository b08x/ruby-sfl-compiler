# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::ChunkArtifactDetector do
  def detect(boundaries, *texts)
    described_class.detect(texts.map { |t| Struct.new(:text).new(t) }, boundaries)
  end

  it "flags both sides of a known mid-sentence split" do
    expect(detect([1], "The system was", "designed for scalability.")).to eq([0, 1])
  end

  it "does not flag a clean boundary where the sentence ends at the chunk end" do
    expect(detect([1], "The system works well.", "Users appreciate it.")).to eq([])
  end

  it "does not flag a capitalized, non-continuation start after a missing terminal mark" do
    expect(detect([1], "See the appendix", "Pricing varies by region.")).to eq([])
  end

  it "flags a capitalized continuation word after a missing terminal mark" do
    expect(detect([1], "The results were promising", "Because the sample size was small")).to eq([0, 1])
  end

  it "returns no duplicate indices when multiple boundaries share a clause" do
    expect(detect([1, 2], "It was", "raining", "heavily that day.")).to eq([0, 1, 2])
  end

  it "ignores out-of-range boundaries instead of raising" do
    expect(detect([0, 5], "Short doc.")).to eq([])
  end

  it "returns an empty array when chunk_boundaries is empty (no PDF chunking happened)" do
    expect(detect([], "The system was", "designed for scalability.")).to eq([])
  end
end
