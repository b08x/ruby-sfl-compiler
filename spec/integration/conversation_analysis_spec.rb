# frozen_string_literal: true

require "spec_helper"
require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"

RSpec.describe SFL::Compiler::ConversationAnalyzer, :integration do
  let(:fixture_path) { File.join(__dir__, "../fixtures/conversations/sample.jsonl") }
  let(:output_dir) { File.join(__dir__, "../../tmp/test_output") }
  let(:analyzer) { described_class.new }

  before(:all) do
    # Skip tests if integration environment is not available
    skip "Integration tests require DATABASE_URL and spaCy setup" unless integration_env_ready?
  end

  before do
    FileUtils.mkdir_p(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir) if File.exist?(output_dir)
  end

  describe "#load_jsonl" do
    it "parses JSONL conversation file" do
      turns = analyzer.load_jsonl(fixture_path)

      expect(turns).to be_an(Array)
      expect(turns.size).to eq(5)
      expect(turns.first).to include(
        name: "Alice",
        is_user: true,
        mes: "Hey, I'm running into a weird issue with the auth flow."
      )
    end

    it "handles malformed JSONL gracefully" do
      malformed_path = File.join(output_dir, "malformed.jsonl")
      File.write(malformed_path, "valid json\n{invalid json\nvalid again")

      turns = analyzer.load_jsonl(malformed_path)

      # Should skip malformed line and parse valid ones
      expect(turns.size).to be < 3
    end
  end

  describe "#analyze_conversation" do
    it "processes JSONL and generates AnalysisResult" do
      result = analyzer.analyze_conversation(fixture_path)

      expect(result).to be_a(SFL::Compiler::Types::AnalysisResult)
      expect(result.metadata[:turn_count]).to eq(5)
      expect(result.metadata[:speakers]).to contain_exactly("Alice", "Bob")

      expect(result.turns).to all(be_a(SFL::Compiler::Types::ConversationTurn))
      expect(result.turns.first.speaker).to eq("Alice")
      expect(result.turns.first.clauses).to all(be_a(SFL::Compiler::Types::AnnotatedClause))

      expect(result.speaker_profiles).to be_a(Hash)
      expect(result.speaker_profiles.keys).to contain_exactly("Alice", "Bob")

      expect(result.tenor_timeline).to be_an(Array)
      expect(result.field_evolution).to be_an(Array)
      expect(result.correlations).to be_a(Hash)
      expect(result.insights).to be_an(Array)
    end

    it "computes speaker profiles correctly" do
      result = analyzer.analyze_conversation(fixture_path)

      alice_profile = result.speaker_profiles["Alice"]
      bob_profile = result.speaker_profiles["Bob"]

      expect(alice_profile).to be_a(SFL::Compiler::Types::SpeakerProfile)
      expect(alice_profile.turn_count).to eq(3)
      expect(alice_profile.avg_tenor).to be_between(0.0, 1.0)

      expect(bob_profile).to be_a(SFL::Compiler::Types::SpeakerProfile)
      expect(bob_profile.turn_count).to eq(2)
      expect(bob_profile.avg_modality).to be_between(0.0, 1.0)
    end

    it "tracks tenor evolution across conversation" do
      result = analyzer.analyze_conversation(fixture_path)

      expect(result.tenor_timeline.size).to eq(5)
      result.tenor_timeline.each do |point|
        expect(point).to include(:turn_id, :tenor, :speaker)
        expect(point[:tenor]).to be_between(0.0, 1.0)
      end
    end
  end

  describe "#generate_outputs" do
    let(:analysis_result) { analyzer.analyze_conversation(fixture_path) }

    it "generates CSV output" do
      outputs = analyzer.generate_outputs(analysis_result, output_dir)

      expect(File.exist?(outputs[:csv])).to be true
      csv_content = File.read(outputs[:csv])
      expect(csv_content).to include("turn_id,speaker,timestamp")
      expect(csv_content.lines.size).to be > 1  # Header + data rows
    end

    it "generates JSON output" do
      outputs = analyzer.generate_outputs(analysis_result, output_dir)

      expect(File.exist?(outputs[:json])).to be true
      json_content = JSON.parse(File.read(outputs[:json]))
      expect(json_content).to include("metadata", "turns", "speaker_profiles")
    end

    it "generates Markdown output" do
      outputs = analyzer.generate_outputs(analysis_result, output_dir)

      expect(File.exist?(outputs[:markdown])).to be true
      markdown_content = File.read(outputs[:markdown])
      expect(markdown_content).to include("# Conversation Analysis")
      expect(markdown_content).to include("## Speaker Profiles")
    end
  end

  # Helper method to check if integration environment is ready
  def self.integration_env_ready?
    return false unless ENV["DATABASE_URL"] || ENV["INTEGRATION_TESTS"]

    # Check if database is accessible
    begin
      db = SFL::Compiler::Database.connect
      db.test_connection
      true
    rescue Sequel::DatabaseError
      false
    end
  end
end
