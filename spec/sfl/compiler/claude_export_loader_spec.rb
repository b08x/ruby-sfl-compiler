# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require "spec_helper"
require "tempfile"

RSpec.describe SFL::Compiler::ClaudeExportLoader do
  let(:fixture_path) { "spec/fixtures/exports/claude_conversations.json" }

  describe ".load" do
    it "returns one Conversation per non-empty conversation in the export" do
      conversations = described_class.load(fixture_path)

      expect(conversations.map(&:id)).to eq(%w[convo-1 convo-2])
    end

    it "maps human/assistant sender to name and is_user" do
      conversations = described_class.load(fixture_path)
      turns = conversations.first.turns

      expect(turns[0]).to include(name: "Human", is_user: true, mes: "Why does this test fail intermittently?")
      expect(turns[1]).to include(name: "Assistant", is_user: false)
    end

    it "prefers text content blocks over the flat .text field when both are present" do
      conversations = described_class.load(fixture_path)
      assistant_turn = conversations.first.turns[1]

      expect(assistant_turn[:mes]).to eq("It's a race condition in the setup block.")
      expect(assistant_turn[:mes]).not_to eq("fallback text")
    end

    it "skips whitespace-only turns without dropping the rest of the conversation" do
      conversations = described_class.load(fixture_path)
      second = conversations.find { |c| c.id == "convo-2" }

      expect(second.turns.size).to eq(1)
      expect(second.turns.first[:mes]).to eq("Empty human turn above should be skipped.")
    end

    it "carries send_date through unmodified for downstream Time.parse" do
      conversations = described_class.load(fixture_path)

      expect(conversations.first.turns.first[:send_date]).to eq("2026-06-01T10:00:00Z")
    end
  end

  describe "produced turns feeding ConversationAnalyzer" do
    it "round-trips through ConversationAnalyzer.load_jsonl without modification" do
      conversations = described_class.load(fixture_path)
      turns = conversations.first.turns

      Tempfile.create(["claude-export", ".jsonl"]) do |f|
        f.write(turns.map { |t| JSON.dump(t) }.join("\n"))
        f.flush

        loaded = SFL::Compiler::Analysis::ConversationAnalyzer.load_jsonl(f.path)
        expect(loaded.size).to eq(2)
        expect(loaded.first[:mes]).to eq("Why does this test fail intermittently?")
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
