# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::CLI do
  describe ".parse" do
    it "parses the conversation subcommand with defaults" do
      parsed = described_class.parse(%w[conversation chat.jsonl])
      expect(parsed).to eq(
        command: :conversation, input: "chat.jsonl",
        options: {
          output_dir: "./output/latest",
          pass1_only: false,
          resume: false,
          narrative: false,
          topics: nil,
          live: false,
          disable_tracing: false,
        }
      )
    end

    it "parses conversation flags" do
      parsed = described_class.parse(%w[conversation chat.jsonl --output-dir ./out --pass1-only])
      expect(parsed[:options]).to eq(output_dir: "./out", pass1_only: true, resume: false, narrative: false,
        topics: nil, live: false, disable_tracing: false)
    end

    it "parses --disable-tracing on conversation" do
      parsed = described_class.parse(%w[conversation chat.jsonl --disable-tracing])
      expect(parsed[:options][:disable_tracing]).to be(true)
    end

    it "parses --live on conversation" do
      parsed = described_class.parse(%w[conversation chat.jsonl --live])
      expect(parsed[:options][:live]).to be(true)
    end

    it "parses documentation with --store" do
      parsed = described_class.parse(%w[documentation docs/ --store])
      expect(parsed[:command]).to eq(:documentation)
      expect(parsed[:input]).to eq("docs/")
      expect(parsed[:options]).to include(store: true)
    end

    it "defaults sprint_id to nil for documentation" do
      parsed = described_class.parse(%w[documentation docs/])
      expect(parsed[:options]).to include(sprint_id: nil)
    end

    it "parses documentation with --sprint-id" do
      parsed = described_class.parse(%w[documentation docs/ --sprint-id sprint-001])
      expect(parsed[:options]).to include(sprint_id: "sprint-001")
    end

    it "parses context with stance filters and limit" do
      parsed = described_class.parse(
        [
          "context",
          "how does tenor work",
          "--mood",
          "declarative",
          "--min-tenor",
          "0.5",
          "--max-modality",
          "0.9",
          "--limit",
          "5",
]
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

    it "parses the knowledge-base subcommand with defaults" do
      parsed = described_class.parse(%w[knowledge-base ~/Notebook])
      expect(parsed[:command]).to eq(:knowledge_base)
      expect(parsed[:input]).to eq("~/Notebook")
      expect(parsed[:options]).to include(
        store: false, images: false, vision_model: nil, resume: false, disable_tracing: false
      )
    end

    it "parses knowledge-base --store --images --vision-model" do
      parsed = described_class.parse(
        %w[knowledge-base ~/Notebook --store --images --vision-model claude-sonnet-4-6 --output-dir ./out]
      )
      expect(parsed[:options]).to include(
        store: true, images: true, vision_model: "claude-sonnet-4-6", output_dir: "./out"
      )
    end

    it "parses knowledge-base --no-images to override default" do
      parsed = described_class.parse(%w[knowledge-base ~/Notebook --images --no-images])
      expect(parsed[:options][:images]).to be(false)
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
      expect(parsed).to eq(command: :tui, input: nil, options: { disable_tracing: false })
    end

    it "parses --disable-tracing on tui" do
      parsed = described_class.parse(%w[tui --disable-tracing])
      expect(parsed[:options][:disable_tracing]).to be(true)
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

  describe ".install_interrupt_trap" do
    after { Signal.trap("INT", "DEFAULT") }

    it "sets the flag on the first SIGINT instead of raising Interrupt" do
      flag = SFL::Compiler::StopFlag.new
      described_class.install_interrupt_trap(flag)

      expect { Process.kill("INT", Process.pid) }.not_to raise_error
      expect(flag.stopped?).to be(true)
    end
  end

  describe ".print_interrupt_status" do
    it "prints the partial progress and a resume command for the given subcommand" do
      result = instance_double(
        SFL::Compiler::Types::AnalysisResult,
        metadata: { turn_count: 2, total: 5 }
      )

      expect { described_class.print_interrupt_status(result, "chat.jsonl", :conversation) }
        .to output(%r{Stopped after 2/5 in chat\.jsonl.*\n.*--resume}m).to_stdout
    end
  end
end
