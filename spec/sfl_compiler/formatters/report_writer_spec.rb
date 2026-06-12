# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe SFL::Compiler::Formatters::ReportWriter do
  let(:result) do
    SFL::Compiler::Types::AnalysisResult.new(
      metadata: { conversation_id: "w", turn_count: 0, speakers: [],
                  analyzed_at: Time.now.iso8601 },
      turns: [], speaker_profiles: {}, tenor_timeline: [],
      field_evolution: [], correlations: {}, insights: []
    )
  end

  it "writes the CSV/JSON/MD trio and returns their paths" do
    Dir.mktmpdir do |dir|
      paths = described_class.write(result, dir)

      expect(paths.keys).to contain_exactly(:csv, :json, :markdown)
      paths.each_value { |p| expect(File).to exist(p) }
      expect(File.read(paths[:markdown])).to include("# Conversation Analysis")
      expect { JSON.parse(File.read(paths[:json])) }.not_to raise_error
    end
  end

  it "creates the output directory if missing" do
    Dir.mktmpdir do |dir|
      nested = File.join(dir, "a/b")
      described_class.write(result, nested)
      expect(Dir).to exist(nested)
    end
  end
end
