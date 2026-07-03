# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SFL::Compiler::Formatters::KBAnnotatedDocWriter do
  def make_artifact(id:, title:, source_file:, section_path: nil, clauses: [make_clause])
    SFL::Compiler::Types::KnowledgeArtifact.new(
      artifact_id: id,
      title:,
      source_file:,
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

  def make_report(artifacts)
    SFL::Compiler::Types::KnowledgeBaseReport.new(
      metadata: {}, artifacts:, migration_manifest: [],
      content_type_distribution: {}, quality_distribution: {}, staleness_flags: []
    )
  end

  it "writes one file per distinct source_file, creating the output dir" do
    report = make_report([
      make_artifact(id: 1, title: "Doc A", source_file: "/notes/doc-a.md"),
      make_artifact(id: 2, title: "Doc B", source_file: "/notes/doc-b.md"),
    ])

    Dir.mktmpdir do |dir|
      paths = described_class.write(report, dir)

      expect(paths.size).to eq(2)
      paths.each { |p| expect(File).to exist(p) }
      expect(File.basename(paths[0])).to eq("doc-a.md")
      expect(File.basename(paths[1])).to eq("doc-b.md")
    end
  end

  it "groups multiple artifacts sharing a source_file into one file" do
    report = make_report([
      make_artifact(id: 1, title: "Doc A", source_file: "/notes/doc-a.md", section_path: "Intro"),
      make_artifact(id: 2, title: "Doc A", source_file: "/notes/doc-a.md", section_path: "Usage"),
    ])

    Dir.mktmpdir do |dir|
      paths = described_class.write(report, dir)

      expect(paths.size).to eq(1)
      content = File.read(paths.first)
      expect(content).to include("## Intro")
      expect(content).to include("## Usage")
      expect(content.index("## Intro")).to be < content.index("## Usage")
    end
  end

  it "disambiguates source files that share a basename in different directories" do
    report = make_report([
      make_artifact(id: 1, title: "A", source_file: "/notes/a/README.md"),
      make_artifact(id: 2, title: "B", source_file: "/notes/b/README.md"),
    ])

    Dir.mktmpdir do |dir|
      paths = described_class.write(report, dir)

      expect(paths.map { |p| File.basename(p) }).to contain_exactly("readme.md", "readme-2.md")
    end
  end

  it "writes into an annotated/ subdirectory of output_dir" do
    report = make_report([make_artifact(id: 1, title: "A", source_file: "/notes/a.md")])

    Dir.mktmpdir do |dir|
      paths = described_class.write(report, dir)

      expect(paths.first).to eq(File.join(dir, "annotated", "a.md"))
    end
  end
end
