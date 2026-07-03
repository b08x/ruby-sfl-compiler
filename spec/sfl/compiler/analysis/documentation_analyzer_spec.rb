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
      expect(result.metadata[:id_label]).to eq("document_id")
    end
  end

  describe "sprint_id" do
    it "omits sprint metadata when sprint_id is not given" do
      Dir.mktmpdir do |dir|
        result = described_class.new(pipeline:, clause_repo:).analyze(write_doc(dir))

        expect(result.metadata).not_to have_key(:sprint_id)
        expect(result.metadata).not_to have_key(:sprint_question_ids)
      end
    end

    it "attaches a QuestionGraph summary when sprint_id is given" do
      Dir.mktmpdir do |dir|
        result = described_class.new(pipeline:, clause_repo:)
          .analyze(write_doc(dir), sprint_id: "sprint-001")

        expect(result.metadata[:sprint_id]).to eq("sprint-001")
        expect(result.metadata[:sprint_question_ids]).to eq(
          %i[modality data_quality tenor_consistency overall_confidence]
        )
        expect(result.metadata[:sprint_roots]).to match_array(
          %i[modality data_quality tenor_consistency]
        )
        expect(result.metadata[:sprint_leaves]).to eq([:overall_confidence])
      end
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

  describe "clause-count threshold" do
    let(:single_section_markdown) do
      <<~MD
        # Section

        This single section has enough prose to clear MarkdownLoader's minimum length threshold for chunking.
      MD
    end

    def write_single_section_doc(dir)
      path = File.join(dir, "doc.md")
      File.write(path, single_section_markdown)
      path
    end

    it "flags low_confidence at 29 clauses (just under the 30 minimum)" do
      allow(pipeline).to receive(:compile) { |_text, document_id:, **| Array.new(29) { annotated_clause(document_id) } }

      Dir.mktmpdir do |dir|
        result = described_class.new(pipeline:, clause_repo:).analyze(write_single_section_doc(dir))

        expect(result.metadata[:clause_count]).to eq(29)
        expect(result.metadata[:low_confidence]).to be(true)
        expect(result.metadata[:low_confidence_threshold]).to eq(30)
      end
    end

    it "does not flag low_confidence at 31 clauses (above the 30 minimum)" do
      allow(pipeline).to receive(:compile) { |_text, document_id:, **| Array.new(31) { annotated_clause(document_id) } }

      Dir.mktmpdir do |dir|
        result = described_class.new(pipeline:, clause_repo:).analyze(write_single_section_doc(dir))

        expect(result.metadata[:clause_count]).to eq(31)
        expect(result.metadata[:low_confidence]).to be(false)
      end
    end

    it "raises InsufficientDataError when the document produces 0 clauses" do
      allow(pipeline).to receive(:compile).and_return([])

      Dir.mktmpdir do |dir|
        path = write_single_section_doc(dir)
        expect { described_class.new(pipeline:, clause_repo:).analyze(path) }
          .to raise_error(SFL::Compiler::InsufficientDataError, /insufficient data/i)
      end
    end
  end

  describe "PDF chunk-boundary artifact detection" do
    def pdf_section(file_id, slug, heading)
      SFL::Compiler::MarkdownLoader::Section.new(
        document_id: "#{file_id}##{slug}", file_id:, heading:,
        heading_level: 1, heading_slug: slug, text: "irrelevant prose long enough to pass.", byte_range: nil
      )
    end

    def clause_with_text(doc_id, text)
      syntactic = SFL::Compiler::Types::SyntacticClause.new(
        id: "syn-#{doc_id}", text:, tokens: [token],
        root_index: 0, sentence_index: 0, document_id: doc_id
      )
      SFL::Compiler::Types::AnnotatedClause.new(
        id: "ann-#{doc_id}", text:, syntactic:,
        ideational: SFL::Compiler::Types::IdeationalPayload.new(
          clause_id: "syn-#{doc_id}", process_type: "material",
          participants: [], circumstances: [], raw_transitivity: {}
        ),
        interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
          clause_id: "syn-#{doc_id}", mood: "declarative", modality_weight: 0.6,
          tenor: 0.7, speaker_attitude: nil, reasoning: nil
        ),
        document_id: doc_id, compiled_at: Time.now
      )
    end

    def write_fake_pdf(dir)
      path = File.join(dir, "report.pdf")
      File.write(path, "fake pdf bytes")
      path
    end

    it "flags a known mid-sentence split across two PDF chunks and excludes it from the turn's averages" do
      sections = [pdf_section("report", "p1-1", "p1 §1"), pdf_section("report", "p2-1", "p2 §1")]
      allow(SFL::Compiler::PdfLoader).to receive(:load).and_return(sections)
      allow(pipeline).to receive(:compile) do |_text, document_id:, **|
        document_id == "report#p1-1" ? [clause_with_text(document_id, "The system was")]
                                      : [clause_with_text(document_id, "designed for scalability.")]
      end

      Dir.mktmpdir do |dir|
        result = described_class.new(pipeline:, clause_repo:).analyze(write_fake_pdf(dir))

        sources = result.turns.flat_map(&:clauses).map { |c| c.interpersonal.annotation_source }
        expect(sources).to eq(%w[chunk_artifact chunk_artifact])
        expect(result.turns[0].avg_tenor).to eq(0.5)
        expect(result.turns[1].avg_tenor).to eq(0.5)
      end
    end

    it "does not flag a clean PDF chunk boundary" do
      sections = [pdf_section("report", "p1-1", "p1 §1"), pdf_section("report", "p2-1", "p2 §1")]
      allow(SFL::Compiler::PdfLoader).to receive(:load).and_return(sections)
      allow(pipeline).to receive(:compile) do |_text, document_id:, **|
        document_id == "report#p1-1" ? [clause_with_text(document_id, "The system works well.")]
                                      : [clause_with_text(document_id, "Users appreciate it.")]
      end

      Dir.mktmpdir do |dir|
        result = described_class.new(pipeline:, clause_repo:).analyze(write_fake_pdf(dir))

        sources = result.turns.flat_map(&:clauses).map { |c| c.interpersonal.annotation_source }
        expect(sources).to eq(%w[llm llm])
      end
    end

    it "never triggers for pure markdown docs, even when section text would otherwise match the heuristic" do
      allow(pipeline).to receive(:compile) do |_text, document_id:, **|
        document_id == "guide#introduction" ? [clause_with_text(document_id, "The system was")]
                                             : [clause_with_text(document_id, "designed for scalability.")]
      end

      Dir.mktmpdir do |dir|
        result = described_class.new(pipeline:, clause_repo:).analyze(write_doc(dir))

        sources = result.turns.flat_map(&:clauses).map { |c| c.interpersonal.annotation_source }
        expect(sources).to eq(%w[llm llm])
      end
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
        # Sections need enough repeated, distinctive vocabulary to clear
        # TopicModeler's default min_cf AND its dominant-topic confidence
        # gate. The previous one-sentence-per-section fixture produced a
        # degenerate model (no word cleared min_cf, infer returned NaN)
        # whose empty distribution the old `|| 0` fallback turned into a
        # fabricated topic 0 — i.e. this test used to pass only because
        # of the fiat-assignment bug the gate now fixes.
        path = File.join(dir, "guide.md")
        File.write(path, <<~MD)
          # Sandbox

          The sandbox uses WebAssembly isolation for untrusted code execution.
          Sandbox isolation relies on WebAssembly memory limits for code execution.
          The WebAssembly sandbox isolates untrusted code execution completely.

          # Telemetry

          Telemetry pipelines ingest OTLP traces for observability monitoring.
          Observability monitoring stores telemetry traces in the OTLP pipelines.
          The telemetry observability traces flow through OTLP monitoring pipelines.

          # Frontend

          The frontend renders virtualized dashboard views with React components.
          React components display virtualized dashboard rendering in the frontend.
          Frontend dashboard rendering uses virtualized React components.
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
