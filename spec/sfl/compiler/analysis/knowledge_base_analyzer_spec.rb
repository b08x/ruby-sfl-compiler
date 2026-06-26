# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SFL::Compiler::Analysis::KnowledgeBaseAnalyzer do
  let(:pipeline)    { instance_double(SFL::Compiler::Pipeline) }
  let(:clause_repo) { instance_double(SFL::Compiler::ClauseRepository, delete_by_document: 0) }

  before do
    allow(pipeline).to receive(:cache).and_return(nil)
    allow(pipeline).to receive(:compile) do |_text, document_id:, **|
      Array.new(5) { make_clause(doc_id: document_id, annotation_source: "llm", modality_weight: 0.7) }
    end
  end

  subject(:analyzer) { described_class.new(pipeline:, clause_repo:) }

  # ── Markdown with YAML frontmatter ────────────────────────────────
  let(:research_md) do
    <<~MD
      ---
      title: Research Note on NLP
      tags:
        - research
        - nlp
      last updated: 2025-06-01
      ---

      # Key Findings

      #{"This section summarises the key findings from the NLP study. " * 5}

      # Methodology

      #{"The methodology chapter describes the research approach in detail. " * 5}
    MD
  end

  let(:tutorial_md) do
    <<~MD
      ---
      title: Ruby Tutorial
      tags:
        - tutorial
        - ruby
      ---

      # Getting Started

      #{"Follow these steps to get started with Ruby on Rails development. " * 5}
    MD
  end

  let(:ai_md) do
    <<~MD
      # AI Summary

      #{"This is the AI generated summary. " * 3}
      AI responses may include mistakes. Please verify the information above.
    MD
  end

  def write_file(dir, name, content)
    path = File.join(dir, name)
    File.write(path, content)
    path
  end

  # ──────────────────────────────────────────────────────────────────
  # Return type
  # ──────────────────────────────────────────────────────────────────
  describe "#analyze return type" do
    it "returns a Types::KnowledgeBaseReport" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        result = analyzer.analyze(dir)
        expect(result).to be_a(SFL::Compiler::Types::KnowledgeBaseReport)
      end
    end

    it "populates required top-level fields" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        result = analyzer.analyze(dir)

        expect(result.metadata[:artifact_count]).to be > 0
        expect(result.metadata[:file_count]).to eq(1)
        expect(result.metadata[:images_analyzed]).to eq(false)
        expect(result.metadata[:analyzed_at]).not_to be_nil
        expect(result.artifacts).not_to be_empty
        expect(result.migration_manifest).not_to be_empty
        expect(result.content_type_distribution).to be_a(Hash)
        expect(result.quality_distribution).to be_a(Hash)
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # Artifact construction
  # ──────────────────────────────────────────────────────────────────
  describe "artifact fields" do
    it "builds a KnowledgeArtifact per section with all required fields" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        artifact = analyzer.analyze(dir).artifacts.first

        expect(artifact).to be_a(SFL::Compiler::Types::KnowledgeArtifact)
        expect(artifact.artifact_id).to be_a(Integer)
        expect(artifact.title).not_to be_empty
        expect(artifact.source_file).not_to be_empty
        expect(artifact.quality_score).to be_between(0.0, 1.0)
        expect(artifact.clauses).not_to be_empty
        expect(artifact.avg_tenor).to be_between(0.0, 1.0)
        expect(artifact.avg_modality).to be_between(0.0, 1.0)
        expect(artifact.annotation_coverage).to have_key(:total)
      end
    end

    it "picks up title from YAML frontmatter" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        titles = analyzer.analyze(dir).artifacts.map(&:title)
        expect(titles).to include("Research Note on NLP")
      end
    end

    it "picks up tags from YAML frontmatter" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        artifact = analyzer.analyze(dir).artifacts.first
        expect(artifact.tags).to include("research", "nlp")
      end
    end

    it "backfills migration_action from the manifest" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        result = analyzer.analyze(dir)
        result.artifacts.each do |a|
          matching = result.migration_manifest.find { |m| m.artifact_id == a.artifact_id }
          expect(a.migration_action).to eq(matching.action)
          expect(a.migration_reason).to eq(matching.reason)
        end
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # Content type classification
  # ──────────────────────────────────────────────────────────────────
  describe "content type classification" do
    it "classifies research-tagged sections as :research_note" do
      Dir.mktmpdir do |dir|
        write_file(dir, "research.md", research_md)
        types = analyzer.analyze(dir).artifacts.map(&:content_type)
        expect(types).to include(:research_note)
      end
    end

    it "classifies tutorial-tagged sections as :tutorial" do
      Dir.mktmpdir do |dir|
        write_file(dir, "tutorial.md", tutorial_md)
        types = analyzer.analyze(dir).artifacts.map(&:content_type)
        expect(types).to include(:tutorial)
      end
    end

    it "classifies AI-disclaimer sections as :ai_generated" do
      Dir.mktmpdir do |dir|
        write_file(dir, "ai.md", ai_md)
        types = analyzer.analyze(dir).artifacts.map(&:content_type)
        expect(types).to include(:ai_generated)
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # Migration manifest
  # ──────────────────────────────────────────────────────────────────
  describe "migration manifest" do
    it "has one entry per artifact" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        result = analyzer.analyze(dir)
        expect(result.migration_manifest.size).to eq(result.artifacts.size)
      end
    end

    it "all manifest entries are MigrationManifestEntry structs" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        result = analyzer.analyze(dir)
        result.migration_manifest.each do |entry|
          expect(entry).to be_a(SFL::Compiler::Types::MigrationManifestEntry)
        end
      end
    end

    it "sends :ai_generated sections to review (verify against ground truth first)" do
      Dir.mktmpdir do |dir|
        write_file(dir, "ai.md", ai_md)
        result = analyzer.analyze(dir)
        ai_entries = result.migration_manifest.select { |e| e.content_type == :ai_generated }
        expect(ai_entries).not_to be_empty
        ai_entries.each { |e| expect(e.action).to eq(:review) }
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # Image handling
  # ──────────────────────────────────────────────────────────────────
  describe "image file handling" do
    it "ignores image files when analyze_images: false (default)" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        # Create a stub image (real PNG header not needed — only extension matters)
        write_file(dir, "diagram.png", "STUB")

        result = analyzer.analyze(dir, analyze_images: false)
        source_files = result.artifacts.map(&:source_file)
        expect(source_files).not_to include(match(/\.png/))
      end
    end

    it "processes image files when analyze_images: true (with stubbed ImageLoader)" do
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        write_file(dir, "diagram.png", "STUB")

        fake_section = make_section(
          text: "A diagram showing the NLP pipeline architecture.",
          heading: "Image: diagram.png",
          frontmatter: { "content_type" => "image", "source_path" => "#{dir}/diagram.png" }
        )
        allow(SFL::Compiler::ImageLoader).to receive(:new).and_return(
          instance_double(SFL::Compiler::ImageLoader, sections: [fake_section])
        )

        result = analyzer.analyze(dir, analyze_images: true)
        expect(result.metadata[:images_analyzed]).to eq(true)
        image_artifacts = result.artifacts.select { |a| a.content_type == :image }
        expect(image_artifacts).not_to be_empty
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # Multiple files
  # ──────────────────────────────────────────────────────────────────
  describe "multi-file directories" do
    it "aggregates artifacts from all markdown files in a directory" do
      Dir.mktmpdir do |dir|
        write_file(dir, "research.md", research_md)
        write_file(dir, "tutorial.md", tutorial_md)

        result = analyzer.analyze(dir)
        expect(result.metadata[:file_count]).to eq(2)
        expect(result.artifacts.size).to be >= 2
      end
    end

    it "builds content_type_distribution correctly across files" do
      Dir.mktmpdir do |dir|
        write_file(dir, "research.md", research_md)
        write_file(dir, "tutorial.md", tutorial_md)

        result = analyzer.analyze(dir)
        dist = result.content_type_distribution
        expect(dist).to be_a(Hash)
        expect(dist.values.sum).to eq(result.artifacts.size)
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # Staleness flags
  # ──────────────────────────────────────────────────────────────────
  describe "staleness flags" do
    let(:stale_md) do
      <<~MD
        ---
        title: Old Note
        last updated: 2020-01-01
        ---

        # Ancient Content

        #{"This content is very old and might be outdated by now. " * 5}
      MD
    end

    it "flags sections with last_updated beyond the 18-month cutoff" do
      Dir.mktmpdir do |dir|
        write_file(dir, "old.md", stale_md)
        result = analyzer.analyze(dir)
        expect(result.staleness_flags).not_to be_empty
        expect(result.staleness_flags.first).to have_key(:artifact_id)
        expect(result.staleness_flags.first).to have_key(:last_updated)
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # on_progress callback
  # ──────────────────────────────────────────────────────────────────
  describe "on_progress callback" do
    it "calls on_progress once per section with artifact_id, total, and title" do
      calls = []
      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        cb_analyzer = described_class.new(pipeline:, clause_repo:, on_progress: ->(h) { calls << h })
        cb_analyzer.analyze(dir)
      end

      expect(calls).not_to be_empty
      calls.each do |h|
        expect(h).to include(:artifact_id, :total, :title)
      end
    end
  end

  # ──────────────────────────────────────────────────────────────────
  # store: true wires clause_repo
  # ──────────────────────────────────────────────────────────────────
  describe "store: true" do
    it "calls pipeline#compile with store: true and invokes delete_by_document" do
      allow(pipeline).to receive(:compile).with(
        anything,
        hash_including(store: true, embed: true)
      ).and_return([make_clause])

      Dir.mktmpdir do |dir|
        write_file(dir, "note.md", research_md)
        analyzer.analyze(dir, store: true)
      end

      expect(clause_repo).to have_received(:delete_by_document).at_least(:once)
    end
  end
end
