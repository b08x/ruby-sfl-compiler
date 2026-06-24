# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SFL::Compiler::Analysis::DocumentationAnalyzer do
  let(:token) do
    SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
  end

  def annotated_clause(doc_id)
    syntactic = SFL::Compiler::Types::SyntacticClause.new(
      id: "syn", text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: doc_id
    )
    SFL::Compiler::Types::AnnotatedClause.new(
      id: "ann", text: "It works.", syntactic:,
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "syn", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "syn", mood: "declarative", modality_weight: 0.6,
        tenor: 0.7, speaker_attitude: nil, reasoning: nil
      ),
      document_id: doc_id, compiled_at: Time.now
    )
  end

  let(:pipeline) { instance_double(SFL::Compiler::Pipeline) }
  let(:clause_repo) { instance_double(SFL::Compiler::ClauseRepository, delete_by_document: 0) }

  before do
    allow(pipeline).to receive(:cache).and_return(nil)
  end

  # Two headings with >40 chars of prose each (MarkdownLoader min_length).
  let(:markdown) do
    <<~MD
      # Introduction

      This introduction section explains the purpose of the document in detail.

      # Usage

      This usage section describes exactly how the tool is operated day to day.
    MD
  end

  def write_doc(dir)
    path = File.join(dir, "guide.md")
    File.write(path, markdown)
    path
  end

  before do
    allow(pipeline).to receive(:compile) do |_text, document_id:, **|
      [annotated_clause(document_id)]
    end
  end

  it "maps sections onto turns (speaker = heading) and labels the report" do
    Dir.mktmpdir do |dir|
      result = described_class.new(pipeline:, clause_repo:)
        .analyze(write_doc(dir))

      expect(result.turns.size).to eq(2)
      expect(result.turns.map(&:speaker)).to eq(%w[Introduction Usage])
      expect(result.turns.map(&:turn_id)).to eq([1, 2])
      expect(result.metadata[:unit_label]).to eq("Section")
      expect(result.metadata[:actor_label]).to eq("Section")
      expect(result.metadata[:actors_list_label]).to eq("Headings")
    end
  end

  it "compiles without storing by default" do
    Dir.mktmpdir do |dir|
      described_class.new(pipeline:, clause_repo:)
        .analyze(write_doc(dir))

      expect(pipeline).to have_received(:compile)
        .with(anything, document_id: "guide#introduction", store: false, embed: false, resume: false)
      expect(clause_repo).not_to have_received(:delete_by_document)
    end
  end

  it "with store: true deletes each section's document_id first, then stores" do
    Dir.mktmpdir do |dir|
      described_class.new(pipeline:, clause_repo:)
        .analyze(write_doc(dir), store: true)

      expect(clause_repo).to have_received(:delete_by_document).with("guide#introduction")
      expect(clause_repo).to have_received(:delete_by_document).with("guide#usage")
      expect(pipeline).to have_received(:compile)
        .with(anything, document_id: "guide#usage", store: true, embed: true, resume: false)
    end
  end

  it "analyzes every .md file in a directory" do
    Dir.mktmpdir do |dir|
      write_doc(dir)
      File.write(File.join(dir, "other.md"), markdown)

      result = described_class.new(pipeline:, clause_repo:)
        .analyze(dir)
      expect(result.turns.size).to eq(4)
    end
  end

  it "dispatches .pdf files in a directory to PdfLoader, not MarkdownLoader" do
    Dir.mktmpdir do |dir|
      write_doc(dir)
      pdf_path = File.join(dir, "report.pdf")
      File.write(pdf_path, "fake pdf bytes")

      pdf_section = SFL::Compiler::MarkdownLoader::Section.new(
        document_id: "report#p1-1", file_id: "report", heading: "p1 §1",
        heading_level: 1, heading_slug: "p1-1",
        text: "PDF-extracted prose long enough to become a turn.", byte_range: nil
      )
      expect(SFL::Compiler::PdfLoader).to receive(:load).with(pdf_path).and_return([pdf_section])

      result = described_class.new(pipeline:, clause_repo:).analyze(dir)
      expect(result.turns.map(&:speaker)).to include("p1 §1")
    end
  end

  it "emits progress events" do
    Dir.mktmpdir do |dir|
      events = []
      described_class.new(pipeline:, clause_repo:,
        on_progress: -> (e) { events << e }).analyze(write_doc(dir))

      expect(events.size).to eq(2)
      expect(events.first).to include(turn_id: 1, total: 2, speaker: "Introduction")
    end
  end

  it "finishes the in-flight section, then stops before starting the next one" do
    Dir.mktmpdir do |dir|
      completed = []
      result = described_class.new(
        pipeline:, clause_repo:,
        on_progress: -> (e) { completed << e[:turn_id] },
        stop_requested: -> { completed.size >= 1 }
      ).analyze(write_doc(dir))

      expect(result.turns.size).to eq(1)
      expect(result.metadata[:interrupted]).to be(true)
      expect(result.metadata[:total]).to eq(2)
    end
  end

  it "marks interrupted false on a normal completion" do
    Dir.mktmpdir do |dir|
      result = described_class.new(pipeline:, clause_repo:, stop_requested: -> { false })
        .analyze(write_doc(dir))

      expect(result.metadata[:interrupted]).to be(false)
      expect(result.metadata[:total]).to eq(2)
    end
  end

  context "with topics: requested" do
    it "skips the pre-pass and omits :topic when fewer than 3 sections" do
      Dir.mktmpdir do |dir|
        described_class.new(pipeline:, clause_repo:)
          .analyze(write_doc(dir), topics: 2)

        expect(pipeline).to have_received(:compile)
          .with(anything, document_id: "guide#introduction", store: false, embed: false, resume: false)
      end
    end

    it "threads a pre-pass topic id/label into pipeline.compile per section" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "guide.md")
        File.write(path, <<~MD)
          # Sandbox

          The sandbox uses WebAssembly isolation for untrusted code execution.

          # Telemetry

          Telemetry pipelines ingest OTLP traces for observability monitoring.

          # Frontend

          The frontend renders virtualized telemetry trace visualizations.
        MD

        described_class.new(pipeline:, clause_repo:)
          .analyze(path, topics: 2)

        expect(pipeline).to have_received(:compile).with(
          anything, document_id: "guide#sandbox", store: false, embed: false, resume: false,
          topic: { id: be_a(Integer), label: be_a(String) }
        ).once
      end
    end

    it "treats topics: 0 as HDP (k: nil) instead of fixed-k LDA" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "guide.md")
        File.write(path, <<~MD)
          # Sandbox

          The sandbox uses WebAssembly isolation for untrusted code execution.

          # Telemetry

          Telemetry pipelines ingest OTLP traces for observability monitoring.

          # Frontend

          The frontend renders virtualized telemetry trace visualizations.
        MD

        expect(SFL::Compiler::Analysis::TopicModeler).to receive(:new)
          .with(k: nil).at_least(:once).and_call_original

        described_class.new(pipeline:, clause_repo:).analyze(path, topics: 0)
      end
    end
  end
end
