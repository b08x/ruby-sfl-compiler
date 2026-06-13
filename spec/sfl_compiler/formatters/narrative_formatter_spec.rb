# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SFL::Compiler::Formatters::NarrativeFormatter do
  let(:report) do
    SFL::Compiler::Types::NarrativeReport.new(
      source: "conv-1", generated_at: Time.at(1_700_000_000),
      overview: "What it is.", cast_and_roles: "Who they are.",
      interpersonal_dynamics: "How tenor moved.",
      conversational_arc: "How it unfolded.",
      data_quality: "What is unmeasured.", takeaways: "What to conclude."
    )
  end

  it "renders the fixed section skeleton in order" do
    md = described_class.new(report).render
    headers = md.scan(/^## (.+)$/).flatten
    expect(headers).to eq([
      "Overview", "Cast & Roles", "Interpersonal Dynamics",
      "Conversational Arc", "Data Quality", "Takeaways"
    ])
    expect(md).to include("# Narrative Report: conv-1")
    expect(md).to include("What it is.")
    expect(md).to include("What to conclude.")
  end

  it "writes to a file" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "narrative_report.md")
      described_class.new(report).write_to(path)
      expect(File.read(path)).to include("# Narrative Report: conv-1")
    end
  end
end
