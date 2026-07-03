# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require "spec_helper"
require "tempfile"

RSpec.describe SFL::Compiler::MistralExportLoader do
  let(:fixture_dir) { "spec/fixtures/exports/mistral" }

  describe ".load" do
    it "loads every chat-*.json file in a directory, skipping conversations with no non-blank turns" do
      conversations = described_class.load(fixture_dir)

      expect(conversations.map(&:id)).to eq(["aaa"])
    end

    it "maps user/assistant role to name and is_user, using content directly (no contentChunks needed)" do
      conversations = described_class.load(fixture_dir)
      turns = conversations.first.turns

      expect(turns[0]).to include(name: "User", is_user: true, mes: "Roast my Ansible playbooks.")
      expect(turns[1]).to include(name: "Mistral", is_user: false,
        mes: "They're so idempotent they're afraid of change.")
    end

    it "carries createdAt through as send_date unmodified" do
      conversations = described_class.load(fixture_dir)

      expect(conversations.first.turns.first[:send_date]).to eq("2026-06-10T09:00:00.000Z")
    end

    context "given a single file instead of a directory" do
      it "loads just that conversation" do
        conversations = described_class.load(File.join(fixture_dir, "chat-aaa.json"))

        expect(conversations.map(&:id)).to eq(["aaa"])
      end
    end
  end

  describe "produced turns feeding ConversationAnalyzer" do
    it "round-trips through ConversationAnalyzer.load_jsonl without modification" do
      conversations = described_class.load(fixture_dir)
      turns = conversations.first.turns

      Tempfile.create(["mistral-export", ".jsonl"]) do |f|
        f.write(turns.map { |t| JSON.dump(t) }.join("\n"))
        f.flush

        loaded = SFL::Compiler::Analysis::ConversationAnalyzer.load_jsonl(f.path)
        expect(loaded.size).to eq(2)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
