require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "Real Conversation Analysis", type: :integration do
  let(:conversation_path) { "/home/b08x/Workspace/Datasets/steve-oliver-2025-08-29@13h25m38s.jsonl" }
  let(:output_dir) { Dir.mktmpdir("sfl_real_output") }

  before do
    skip "Conversation file not found" unless File.exist?(conversation_path)
  end

  after do
    FileUtils.rm_rf(output_dir) if File.exist?(output_dir)
  end

  it "analyzes real steve-oliver conversation" do
    require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"

    analyzer = SFL::Compiler::ConversationAnalyzer.new(
      input_file: conversation_path,
      output_dir: output_dir
    )

    result = analyzer.analyze

    expect(result.turns.count).to eq(28)
    expect(result.speaker_profiles.keys).to contain_exactly("Robert", "Steve")

    # Verify tenor patterns from design spec
    robert_profile = result.speaker_profiles["Robert"]
    steve_profile = result.speaker_profiles["Steve"]

    expect(robert_profile.avg_tenor).to be < steve_profile.avg_tenor
    expect(steve_profile.avg_tenor).to be > 0.6  # Formal
    expect(robert_profile.avg_tenor).to be < 0.5  # Casual
  end

  it "generates all output files" do
    require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"

    analyzer = SFL::Compiler::ConversationAnalyzer.new(
      input_file: conversation_path,
      output_dir: output_dir
    )

    analyzer.analyze
    analyzer.write_outputs

    expect(File.exist?(File.join(output_dir, "conversation_analysis.csv"))).to be true
    expect(File.exist?(File.join(output_dir, "conversation_analysis.json"))).to be true
    expect(File.exist?(File.join(output_dir, "conversation_analysis.md"))).to be true
  end

  it "identifies tenor shifts" do
    require_relative "../../scripts/sfl_analysis/templates/conversation_analysis_template"

    analyzer = SFL::Compiler::ConversationAnalyzer.new(
      input_file: conversation_path,
      output_dir: output_dir
    )

    result = analyzer.analyze

    # Should detect shift from Robert (casual) to Steve (formal)
    shifts = result.turns.select { |t| t.tenor_shift && t.tenor_shift.abs > 0.15 }
    expect(shifts).not_to be_empty
  end
end
