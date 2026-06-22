# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SFL::Compiler::Analysis::ConversationAnalyzer do
  let(:jsonl_path) { "spec/fixtures/conversations/sample.jsonl" }

  let(:token) do
    SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
  end

  def annotated_clause(doc_id, tenor: 0.7, source: "llm")
    syntactic = SFL::Compiler::Types::SyntacticClause.new(
      id: "syn-#{doc_id}", text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: doc_id
    )
    SFL::Compiler::Types::AnnotatedClause.new(
      id: "ann-#{doc_id}", text: "It works.", syntactic:,
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "syn-#{doc_id}", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "syn-#{doc_id}", mood: "declarative",
        modality_weight: 0.6, tenor:,
        speaker_attitude: nil, reasoning: nil, annotation_source: source
      ),
      document_id: doc_id, compiled_at: Time.now
    )
  end

  let(:pipeline) { instance_double(SFL::Compiler::Pipeline) }

  describe "#analyze (full pipeline)" do
    before do
      allow(pipeline).to receive(:cache).and_return(nil)
      allow(pipeline).to receive(:compile) do |_text, document_id:, **|
        [annotated_clause(document_id)]
      end
    end

    it "compiles each turn with store/embed off and returns an AnalysisResult" do
      result = described_class.new(pipeline:).analyze(jsonl_path)

      expect(result).to be_a(SFL::Compiler::Types::AnalysisResult)
      expect(result.turns.size).to eq(5)
      expect(pipeline).to have_received(:compile)
        .with(anything, document_id: "turn-1", store: false, embed: false, resume: false)
    end

    it "fills metadata from the file and turns" do
      result = described_class.new(pipeline:).analyze(jsonl_path)

      expect(result.metadata[:conversation_id]).to eq("sample")
      expect(result.metadata[:turn_count]).to eq(5)
      expect(result.metadata[:speakers]).to match_array(result.turns.map(&:speaker).uniq)
    end

    it "emits a progress event per turn" do
      events = []
      described_class.new(pipeline:, on_progress: -> (e) { events << e })
        .analyze(jsonl_path)

      expect(events.size).to eq(5)
      expect(events.first).to include(turn_id: 1, total: 5)
      expect(events.first).to include(:speaker, :elapsed, :clause_count, :defaulted)
    end

    it "fires on_turn_start before on_progress, before the expensive compile step" do
      calls = []
      allow(pipeline).to receive(:compile) do |_t, document_id:, **|
        calls << :compiled
        [annotated_clause(document_id)]
      end

      described_class.new(
        pipeline:,
        on_turn_start: -> (e) { calls << [:start, e[:turn_id], e[:total], e[:speaker]] },
        on_progress: -> (e) { calls << [:progress, e[:turn_id]] }
      ).analyze(jsonl_path)

      expect(calls.first(3)).to eq([[:start, 1, 5, "Alice"], :compiled, [:progress, 1]])
    end

    it "computes tenor shifts and speaker profiles" do
      result = described_class.new(pipeline:).analyze(jsonl_path)

      expect(result.turns[1].tenor_shift).not_to be_nil
      expect(result.speaker_profiles).not_to be_empty
      expect(result.tenor_timeline.size).to eq(5)
    end

    it "treats topics: 0 as HDP (k: nil) instead of fixed-k LDA" do
      expect(SFL::Compiler::Analysis::TopicModeler).to receive(:new)
        .with(k: nil).at_least(:once).and_call_original

      described_class.new(pipeline:).analyze(jsonl_path, topics: 0)
    end

    it "passes a positive topics count straight through as fixed-k LDA" do
      expect(SFL::Compiler::Analysis::TopicModeler).to receive(:new)
        .with(k: 2).at_least(:once).and_call_original

      described_class.new(pipeline:).analyze(jsonl_path, topics: 2)
    end
  end

  describe "#analyze (pass_one_only: true)" do
    before do
      allow(pipeline).to receive(:cache).and_return(nil)
      allow(pipeline).to receive(:compile_pass_one) do |_text, document_id:|
        syntactic = SFL::Compiler::Types::SyntacticClause.new(
          id: "s", text: "It works.", tokens: [token],
          root_index: 0, sentence_index: 0, document_id:
        )
        ideational = SFL::Compiler::Types::IdeationalPayload.new(
          clause_id: "s", process_type: "material",
          participants: [], circumstances: [], raw_transitivity: {}
        )
        [[syntactic, ideational]]
      end
    end

    it "skips Pass 2 and stubs interpersonal values with provenance" do
      result = described_class.new(pipeline:, pass_one_only: true)
        .analyze(jsonl_path)

      sources = result.turns.flat_map(&:clauses)
        .map { |c| c.interpersonal.annotation_source }
      expect(sources.uniq).to eq(["stub"])
    end
  end

  describe "malformed JSONL" do
    before do
      allow(pipeline).to receive(:cache).and_return(nil)
    end

    it "skips unparseable lines instead of raising" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "bad.jsonl")
        File.write(path, <<~LINES)
          {"name":"A","send_date":"2026-01-01 10:00","mes":"Hi."}
          not json at all
          {"name":"B","send_date":"2026-01-01 10:01","mes":"Hello."}
        LINES
        allow(pipeline).to receive(:compile) { |_t, document_id:, **| [annotated_clause(document_id)] }

        result = described_class.new(pipeline:).analyze(path)
        expect(result.turns.size).to eq(2)
      end
    end

    it "returns an empty result when no lines parse" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "empty.jsonl")
        File.write(path, "not json\nalso not json\n")

        result = described_class.new(pipeline:).analyze(path)
        expect(result.turns).to eq([])
        expect(result.insights).to eq([])
      end
    end

    it "skips a SillyTavern group-chat metadata header line (valid JSON, no :mes)" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "group_chat.jsonl")
        File.write(path, <<~LINES)
          {"chat_metadata":{},"user_name":"Robert","character_name":"Steve"}
          {"name":"Robert","is_user":true,"send_date":"2026-01-01 10:00","mes":"Hi.","extra":{}}
          {"name":"Steve","is_user":false,"send_date":"2026-01-01 10:01","mes":"Hello.","extra":{}}
        LINES
        allow(pipeline).to receive(:compile) { |_t, document_id:, **| [annotated_clause(document_id)] }

        result = described_class.new(pipeline:).analyze(path)
        expect(result.turns.size).to eq(2)
        expect(result.turns.map(&:speaker)).to eq(%w[Robert Steve])
      end
    end
  end
end
