# frozen_string_literal: true

require "spec_helper"
# instance_double(Sequel::Database) needs the constant loaded. In a real
# run it comes in transitively via SFL::Compiler::Database (storage/
# database.rb requires "sequel"), but this spec stubs Bootstrap.call
# entirely, so Database is never autoloaded and Sequel stays undefined
# without this explicit require.
require "sequel"

RSpec.describe SFL::Compiler::CompileTurnJob do
  let(:token) do
    SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
  end

  let(:annotated_clause) do
    syntactic = SFL::Compiler::Types::SyntacticClause.new(
      id: "syn-1", text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: "turn-1"
    )
    SFL::Compiler::Types::AnnotatedClause.new(
      id: "ann-1", text: "It works.", syntactic:,
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "syn-1", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "syn-1", mood: "declarative",
        modality_weight: 0.6, tenor: 0.7,
        speaker_attitude: nil, reasoning: nil, annotation_source: "llm"
      ),
      document_id: "turn-1", compiled_at: Time.now
    )
  end

  let(:pipeline) { instance_double(SFL::Compiler::Pipeline) }
  let(:db) { instance_double(Sequel::Database) }
  let(:bootstrap_context) do
    SFL::Compiler::Bootstrap::Context.new(db:, config: SFL::Compiler::Configuration.new)
  end

  before do
    allow(SFL::Compiler::Bootstrap).to receive(:call).and_return(bootstrap_context)
    allow(SFL::Compiler::Pipeline).to receive(:new).and_return(pipeline)
    allow(pipeline).to receive(:compile).and_return([annotated_clause])
  end

  it "compiles the turn via the Pipeline and outputs a JSON-safe ConversationTurn Hash" do
    job = described_class.new(
      params: {
        turn_data: { name: "Alice", send_date: "2024-01-01 00:00:00", mes: "It works." },
        turn_id: 1,
      }
    )

    job.perform

    expect(pipeline).to have_received(:compile)
      .with("It works.", document_id: "turn-1", store: false, embed: false, resume: false, source_type: "chat_native")

    turn = SFL::Compiler::Types.load_conversation_turn(
      JSON.parse(JSON.generate(job.output_payload), symbolize_names: true)
    )
    expect(turn.turn_id).to eq(1)
    expect(turn.speaker).to eq("Alice")
    expect(turn.clauses.size).to eq(1)
    expect(turn.dominant_mood).to eq("declarative")
  end

  describe "with a TopicModelJob dependency" do
    def pre_turn_hash(turn_id:, dominant_topic: 0, topic_distribution: { 0 => 0.9 }, semantic_coherence_score: 0.72)
      { turn_id:, topic_distribution:, dominant_topic:, semantic_coherence_score: }
    end

    def topic_model_payload(pre_turns:, topic_labels:, topic_shifts: [])
      {
        id: "TopicModelJob-1",
        class: "SFL::Compiler::TopicModelJob",
        output: { pre_turns:, topic_labels:, topic_shifts: },
      }
    end

    let(:topic_payload) do
      topic_model_payload(pre_turns: [pre_turn_hash(turn_id: 1)], topic_labels: { 0 => %w[deploy pipeline] })
    end

    it "attaches topic_distribution/dominant_topic/semantic_coherence_score from its pre_turn payload" do
      job = described_class.new(
        params: { turn_data: { name: "Alice", send_date: "2024-01-01 00:00:00", mes: "It works." }, turn_id: 1 }
      )
      job.payloads = [topic_payload]

      job.perform

      turn = SFL::Compiler::Types.load_conversation_turn(
        JSON.parse(JSON.generate(job.output_payload), symbolize_names: true)
      )
      expect(turn.dominant_topic).to eq(0)
      expect(turn.semantic_coherence_score).to eq(0.72)
      expect(turn.topic_distribution).to eq(:"0" => 0.9) # JSON round trip stringifies this Hash's keys too
    end

    it "forwards topic: and semantic_coherence_score: to Pipeline#compile when a pre_turn is present" do
      job = described_class.new(
        params: { turn_data: { name: "Alice", send_date: "2024-01-01 00:00:00", mes: "It works." }, turn_id: 1 }
      )
      job.payloads = [topic_payload]

      job.perform

      expect(pipeline).to have_received(:compile).with(
        "It works.", document_id: "turn-1", store: false, embed: false, resume: false, source_type: "chat_native",
        topic: { id: 0, label: "deploy" }, semantic_coherence_score: 0.72
      )
    end

    it "calls Pipeline#compile without topic:/semantic_coherence_score: when no TopicModelJob payload is present" do
      job = described_class.new(
        params: { turn_data: { name: "Alice", send_date: "2024-01-01 00:00:00", mes: "It works." }, turn_id: 1 }
      )

      job.perform

      expect(pipeline).to have_received(:compile)
        .with("It works.", document_id: "turn-1", store: false, embed: false, resume: false, source_type: "chat_native")
    end
  end
end
