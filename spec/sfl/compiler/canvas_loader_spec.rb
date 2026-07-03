# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe SFL::Compiler::CanvasLoader do
  def write_canvas(dir, name, nodes)
    path = File.join(dir, name)
    File.write(path, JSON.dump(nodes:, edges: []))
    path
  end

  describe "#to_a" do
    it "extracts text nodes as sections, skipping group and file nodes" do
      Dir.mktmpdir do |dir|
        path = write_canvas(dir, "board.canvas", [
          { id: "grp-1", type: "group", x: 0, y: 0, width: 100, height: 100, label: "Projects" },
          { id: "file-1", type: "file", x: 0, y: 0, width: 100, height: 100, file: "Notes/other.md" },
          {
            id: "text-1",
            type: "text",
            x: 0,
            y: 0,
            width: 300,
            height: 200,
            text: "This canvas node has enough prose to survive the min_length filter easily.",
          },
        ])

        sections = described_class.load(path)

        expect(sections.size).to eq(1)
        expect(sections.first.text).to include("enough prose")
        expect(sections.first.heading_slug).to eq("text-1")
      end
    end

    it "skips text nodes shorter than min_length" do
      Dir.mktmpdir do |dir|
        path = write_canvas(dir, "board.canvas", [
          { id: "text-1", type: "text", x: 0, y: 0, width: 100, height: 100, text: "too short" },
        ])

        expect(described_class.load(path)).to be_empty
      end
    end

    it "derives document_id from file_id and node id" do
      Dir.mktmpdir do |dir|
        path = write_canvas(dir, "roadmap.canvas", [
          {
            id: "note-a",
            type: "text",
            x: 0,
            y: 0,
            width: 300,
            height: 200,
            text: "Long enough text content to pass the default min_length threshold check.",
          },
        ])

        sections = described_class.load(path)

        expect(sections.first.document_id).to eq("roadmap#note-a")
        expect(sections.first.file_id).to eq("roadmap")
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
