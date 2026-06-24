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
      .with("It works.", document_id: "turn-1", store: false, embed: false, resume: false)

    turn = SFL::Compiler::Types.load_conversation_turn(
      JSON.parse(JSON.generate(job.output_payload), symbolize_names: true)
    )
    expect(turn.turn_id).to eq(1)
    expect(turn.speaker).to eq("Alice")
    expect(turn.clauses.size).to eq(1)
    expect(turn.dominant_mood).to eq("declarative")
  end
end
