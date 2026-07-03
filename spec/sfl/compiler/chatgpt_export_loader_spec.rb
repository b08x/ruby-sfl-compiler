# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require "spec_helper"
require "tempfile"

RSpec.describe SFL::Compiler::ChatGPTExportLoader do
  let(:fixture_path) { "spec/fixtures/exports/chatgpt_conversations.json" }

  describe ".load" do
    it "linearizes the tree into chronological turns, excluding the empty conversation" do
      conversations = described_class.load(fixture_path)

      expect(conversations.map(&:id)).to eq(["convo-1"])
    end

    it "filters out system-role nodes" do
      conversations = described_class.load(fixture_path)
      turns = conversations.first.turns

      expect(turns.size).to eq(2)
      expect(turns.map { |t| t[:name] }).to eq(%w[User ChatGPT])
    end

    it "maps user/assistant role to name and is_user" do
      conversations = described_class.load(fixture_path)
      turns = conversations.first.turns

      expect(turns[0]).to include(name: "User", is_user: true, mes: "What is reciprocal rank fusion?")
      expect(turns[1]).to include(name: "ChatGPT", is_user: false,
        mes: "RRF merges ranked lists by summing 1/(k+rank).")
    end

    it "converts epoch create_time to an ISO8601 send_date" do
      conversations = described_class.load(fixture_path)

      expect(conversations.first.turns.first[:send_date]).to eq(Time.at(1_780_000_001).iso8601)
    end
  end

  describe "produced turns feeding ConversationAnalyzer" do
    it "round-trips through ConversationAnalyzer.load_jsonl without modification" do
      conversations = described_class.load(fixture_path)
      turns = conversations.first.turns

      Tempfile.create(["chatgpt-export", ".jsonl"]) do |f|
        f.write(turns.map { |t| JSON.dump(t) }.join("\n"))
        f.flush

        loaded = SFL::Compiler::Analysis::ConversationAnalyzer.load_jsonl(f.path)
        expect(loaded.size).to eq(2)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
