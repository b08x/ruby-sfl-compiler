# frozen_string_literal: true

require "spec_helper"

# Note: Pipeline#initialize constructs PassOneEngine (which requires ruby-spacy)
# and uses Zeitwerk autoloading. Since spacy isn't installed in CI, we bypass
# the constructor with Pipeline.allocate and inject mocks directly via
# instance_variable_set. This exercises the orchestration logic without
# needing spaCy or DSPy.
RSpec.describe SFL::Compiler::Pipeline do
  # Real Type objects as fixtures
  let(:token) do
    SFL::Compiler::Types::SyntacticToken.new(
      text: "processes", lemma: "process", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
  end

  let(:clause) do
    SFL::Compiler::Types::SyntacticClause.new(
      id: "clause-1", text: "The system processes data.",
      tokens: [token], root_index: 0, sentence_index: 0, document_id: "doc-1"
    )
  end

  let(:ideational) do
    SFL::Compiler::Types::IdeationalPayload.new(
      clause_id: "clause-1", process_type: "material",
      participants: [], circumstances: [], raw_transitivity: {}
    )
  end

  let(:interpersonal) do
    SFL::Compiler::Types::InterpersonalPayload.new(
      clause_id: "clause-1", mood: "declarative", modality_weight: 0.7,
      tenor: 0.6, speaker_attitude: "assertive", reasoning: "test"
    )
  end

  let(:annotated_clause) do
    SFL::Compiler::Types::AnnotatedClause.new(
      id: "annotated-1", text: "The system processes data.",
      syntactic: clause, ideational: ideational, interpersonal: interpersonal,
      document_id: "doc-1", compiled_at: Time.now
    )
  end

  # Doubles for engines, repositories, embedder
  let(:pass_one) { instance_double("PassOneEngine", process: [clause]) }
  let(:ideational_extractor) { instance_double("IdeationalExtractor", extract: ideational) }
  let(:pass_two) do
    instance_double("PassTwoEngine", annotate: annotated_clause,
      annotate_batch: [annotated_clause])
  end
  let(:clause_repo) { instance_double("ClauseRepository", store: true) }
  let(:embedding_repo) { instance_double("EmbeddingRepository", store: true) }
  let(:embedder) { instance_double("Embedder", embed: [0.1, 0.2, 0.3]) }
  let(:logger) { instance_double("Journald::Logger", send_message: nil) }
  let(:db) { double("db") }

  def build_pipeline(embedder_override: nil)
    p = SFL::Compiler::Pipeline.allocate
    p.instance_variable_set(:@db, db)
    p.instance_variable_set(:@pass_one, pass_one)
    p.instance_variable_set(:@ideational_extractor, ideational_extractor)
    p.instance_variable_set(:@pass_two, pass_two)
    p.instance_variable_set(:@clause_repo, clause_repo)
    p.instance_variable_set(:@embedding_repo, embedding_repo)
    p.instance_variable_set(:@embedder, embedder_override)
    p.instance_variable_set(:@logger, logger)
    p
  end

  describe "#compile" do
    context "happy path with default options" do
      let(:pipeline) { build_pipeline }

      before do
        allow(pass_one).to receive(:process)
          .with("Hello world", document_id: "doc-1").and_return([clause])
      end

      it "returns array of annotated clauses" do
        result = pipeline.compile("Hello world", document_id: "doc-1")
        expect(result).to eq([annotated_clause])
      end

      it "passes text and document_id to PassOneEngine" do
        pipeline.compile("Hello world", document_id: "doc-1")
        expect(pass_one).to have_received(:process)
          .with("Hello world", document_id: "doc-1")
      end

      it "extracts ideational payload for each clause" do
        pipeline.compile("Hello world", document_id: "doc-1")
        expect(ideational_extractor).to have_received(:extract).with(clause).once
      end

      it "annotates all clauses in one batched PassTwoEngine call" do
        pipeline.compile("Hello world", document_id: "doc-1")
        expect(pass_two).to have_received(:annotate_batch)
          .with([[clause, ideational]]).once
        expect(pass_two).not_to have_received(:annotate)
      end

      it "stores each annotated clause by default" do
        pipeline.compile("Hello world", document_id: "doc-1")
        expect(clause_repo).to have_received(:store).with(annotated_clause).once
      end

      it "does not embed when no embedder is set" do
        pipeline.compile("Hello world", document_id: "doc-1")
        expect(embedder).not_to have_received(:embed)
        expect(embedding_repo).not_to have_received(:store)
      end
    end

    context "with store: false" do
      let(:pipeline) { build_pipeline }
      before { allow(pass_one).to receive(:process).and_return([clause]) }

      it "does not store clauses" do
        pipeline.compile("Hello world", store: false)
        expect(clause_repo).not_to have_received(:store)
      end
    end

    context "with embed: true and embedder set" do
      let(:pipeline) { build_pipeline(embedder_override: embedder) }
      before { allow(pass_one).to receive(:process).and_return([clause]) }

      it "calls embedder and stores the embedding" do
        pipeline.compile("Hello world")
        expect(embedder).to have_received(:embed).with("The system processes data.").once
        expect(embedding_repo).to have_received(:store)
          .with("annotated-1", [0.1, 0.2, 0.3]).once
      end
    end

    context "with embed: true but no embedder" do
      let(:pipeline) { build_pipeline(embedder_override: nil) }
      before { allow(pass_one).to receive(:process).and_return([clause]) }

      it "does not call any embedder" do
        pipeline.compile("Hello world", embed: true)
        expect(embedder).not_to have_received(:embed)
        expect(embedding_repo).not_to have_received(:store)
      end
    end

    context "with embed: false" do
      let(:pipeline) { build_pipeline(embedder_override: embedder) }
      before { allow(pass_one).to receive(:process).and_return([clause]) }

      it "does not call embedder" do
        pipeline.compile("Hello world", embed: false)
        expect(embedder).not_to have_received(:embed)
      end
    end

    context "when pass one produces no clauses" do
      let(:pipeline) { build_pipeline }
      before do
        allow(pass_one).to receive(:process).and_return([])
        # mirror the real engine: an empty batch annotates to an empty array
        allow(pass_two).to receive(:annotate_batch).with([]).and_return([])
      end

      it "returns an empty array" do
        result = pipeline.compile("...")
        expect(result).to eq([])
      end

      it "does not call pass two" do
        pipeline.compile("...")
        expect(pass_two).not_to have_received(:annotate)
      end
    end

    context "when PassOneEngine raises PassOneError" do
      let(:pipeline) { build_pipeline }
      before do
        allow(pass_one).to receive(:process)
          .and_raise(SFL::Compiler::PassOneError, "spaCy crashed")
      end

      it "propagates the error to the caller" do
        expect { pipeline.compile("Hello world") }
          .to raise_error(SFL::Compiler::PassOneError, /spaCy crashed/)
      end
    end

    context "when PassTwoEngine raises PassTwoError" do
      let(:pipeline) { build_pipeline }
      before do
        allow(pass_one).to receive(:process).and_return([clause])
        allow(pass_two).to receive(:annotate_batch)
          .and_raise(SFL::Compiler::PassTwoError, "DSPy unavailable")
      end

      it "propagates the error to the caller" do
        expect { pipeline.compile("Hello world") }
          .to raise_error(SFL::Compiler::PassTwoError, /DSPy unavailable/)
      end
    end

    context "with multiple clauses" do
      let(:clause_2) do
        SFL::Compiler::Types::SyntacticClause.new(
          id: "clause-2", text: "It works.",
          tokens: [token], root_index: 0, sentence_index: 0, document_id: "doc-1"
        )
      end

      let(:ideational_2) do
        SFL::Compiler::Types::IdeationalPayload.new(
          clause_id: "clause-2", process_type: "material",
          participants: [], circumstances: [], raw_transitivity: {}
        )
      end

      let(:annotated_clause_2) do
        SFL::Compiler::Types::AnnotatedClause.new(
          id: "annotated-2", text: "It works.",
          syntactic: clause_2, ideational: ideational_2, interpersonal: interpersonal,
          document_id: "doc-1", compiled_at: Time.now
        )
      end

      let(:pipeline) { build_pipeline }

      before do
        allow(pass_one).to receive(:process).and_return([clause, clause_2])
        allow(ideational_extractor).to receive(:extract).with(clause).and_return(ideational)
        allow(ideational_extractor).to receive(:extract).with(clause_2).and_return(ideational_2)
        allow(pass_two).to receive(:annotate_batch)
          .with([[clause, ideational], [clause_2, ideational_2]])
          .and_return([annotated_clause, annotated_clause_2])
      end

      it "processes all clauses in order" do
        result = pipeline.compile("...")
        expect(result).to eq([annotated_clause, annotated_clause_2])
      end

      it "pairs the right ideational payload with each clause in the batch" do
        pipeline.compile("...")
        expect(pass_two).to have_received(:annotate_batch)
          .with([[clause, ideational], [clause_2, ideational_2]])
      end
    end
  end

  describe "#compile_pass_one" do
    let(:pipeline) { build_pipeline }

    before do
      allow(pass_one).to receive(:process)
        .with("Hello world", document_id: "doc-1").and_return([clause])
    end

    it "returns pairs of [clause, ideational]" do
      result = pipeline.compile_pass_one("Hello world", document_id: "doc-1")
      expect(result).to eq([[clause, ideational]])
    end

    it "does not call PassTwoEngine" do
      pipeline.compile_pass_one("Hello world", document_id: "doc-1")
      expect(pass_two).not_to have_received(:annotate)
    end

    it "does not store anything" do
      pipeline.compile_pass_one("Hello world", document_id: "doc-1")
      expect(clause_repo).not_to have_received(:store)
    end
  end

  describe "#compile_pass_two" do
    let(:pipeline) { build_pipeline }

    it "delegates to PassTwoEngine#annotate" do
      result = pipeline.compile_pass_two(clause, ideational)
      expect(result).to eq(annotated_clause)
    end

    it "does not re-run Pass 1" do
      pipeline.compile_pass_two(clause, ideational)
      expect(pass_one).not_to have_received(:process)
    end

    it "does not call ideational extractor" do
      pipeline.compile_pass_two(clause, ideational)
      expect(ideational_extractor).not_to have_received(:extract)
    end
  end
end