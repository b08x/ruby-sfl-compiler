# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::CLI do
  describe ".parse" do
    it "parses the conversation subcommand with defaults" do
      parsed = described_class.parse(%w[conversation chat.jsonl])
      expect(parsed).to eq(
        command: :conversation, input: "chat.jsonl",
        options: { output_dir: "./output/latest", pass1_only: false, resume: false, narrative: false, topics: nil }
      )
    end

    it "parses conversation flags" do
      parsed = described_class.parse(%w[conversation chat.jsonl --output-dir ./out --pass1-only])
      expect(parsed[:options]).to eq(output_dir: "./out", pass1_only: true, resume: false, narrative: false,
        topics: nil)
    end

    it "parses documentation with --store" do
      parsed = described_class.parse(%w[documentation docs/ --store])
      expect(parsed[:command]).to eq(:documentation)
      expect(parsed[:input]).to eq("docs/")
      expect(parsed[:options]).to include(store: true)
    end

    it "parses context with stance filters and limit" do
      parsed = described_class.parse(
        ["context", "how does tenor work", "--mood", "declarative",
         "--min-tenor", "0.5", "--max-modality", "0.9", "--limit", "5"]
      )
      expect(parsed[:command]).to eq(:context)
      expect(parsed[:input]).to eq("how does tenor work")
      expect(parsed[:options]).to include(
        filters: { mood: "declarative", min_tenor: 0.5, max_modality: 0.9 },
        limit: 5
      )
    end

    it "parses narrate with input and output-dir" do
      parsed = described_class.parse(%w[narrate report.json --output-dir ./out])
      expect(parsed[:command]).to eq(:narrate)
      expect(parsed[:input]).to eq("report.json")
      expect(parsed[:options][:output_dir]).to eq("./out")
    end

    it "defaults narrate output-dir to nil (resolved to the JSON's directory at run time)" do
      parsed = described_class.parse(%w[narrate report.json])
      expect(parsed[:options][:output_dir]).to be_nil
    end

    it "parses --narrative on conversation" do
      parsed = described_class.parse(%w[conversation chat.jsonl --narrative])
      expect(parsed[:options][:narrative]).to be(true)
    end

    it "parses --narrative on documentation" do
      parsed = described_class.parse(%w[documentation docs/ --narrative])
      expect(parsed[:options][:narrative]).to be(true)
    end

    it "raises UsageError for an unknown subcommand" do
      expect { described_class.parse(%w[bogus x]) }
        .to raise_error(SFL::Compiler::CLI::UsageError, /Unknown subcommand/)
    end

    it "raises UsageError when the input argument is missing" do
      expect { described_class.parse(%w[conversation]) }
        .to raise_error(SFL::Compiler::CLI::UsageError, /requires an input/)
    end

    it "parses tui with no input argument required" do
      parsed = described_class.parse(%w[tui])
      expect(parsed).to eq(command: :tui, input: nil, options: {})
    end
  end

  describe ".run_tui" do
    it "builds a TUI::Menu with a deferred chat_session_builder and runs it" do
      menu = instance_double(SFL::Compiler::TUI::Menu, run: nil)
      expect(SFL::Compiler::TUI::Menu).to receive(:new) do |chat_session_builder:|
        expect(chat_session_builder).to respond_to(:call)
        menu
      end

      described_class.run_tui(nil, {})

      expect(menu).to have_received(:run)
    end
  end
end
