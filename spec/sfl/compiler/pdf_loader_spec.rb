# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::PdfLoader do
  def chunk(content, first_page: 1)
    Kreuzberg::Result::Chunk.new(content, nil, nil, nil, 0, 1, first_page, first_page, nil, nil)
  end

  def stub_extraction(chunks:, content: "", metadata: nil, extracted_keywords: [])
    result = instance_double(Kreuzberg::Result, content:, chunks:, metadata:, extracted_keywords:)
    allow(Kreuzberg).to receive(:extract_file_sync).and_return(result)
  end

  describe "#each_section / .load" do
    it "builds one Section per chunk, anchored to first_page" do
      stub_extraction(chunks: [
        chunk("This is a long enough first chunk of prose to clear the minimum length.", first_page: 1),
        chunk("This is a long enough second chunk of prose to clear the minimum length.", first_page: 2),
      ])

      sections = described_class.load("/tmp/fake.pdf")

      expect(sections.size).to eq(2)
      expect(sections.map(&:document_id)).to eq(%w[fake#p1-1 fake#p2-2])
      expect(sections.map(&:heading)).to eq(["p1 §1", "p2 §2"])
    end

    it "skips chunks shorter than min_length" do
      stub_extraction(chunks: [
        chunk("too short", first_page: 1),
        chunk("This one is long enough to clear the default 40-character minimum length threshold.", first_page: 1),
      ])

      sections = described_class.load("/tmp/fake.pdf")

      expect(sections.size).to eq(1)
      expect(sections.first.text).to start_with("This one is long enough")
    end

    it "does not skip short chunks when skip_empty: false" do
      stub_extraction(chunks: [chunk("short", first_page: 1)])

      sections = described_class.load("/tmp/fake.pdf", skip_empty: false)

      expect(sections.size).to eq(1)
    end

    it "falls back to the whole extracted content as one section when chunks is empty" do
      stub_extraction(chunks: [], content: "Whole-document fallback text, long enough to clear the threshold easily.")

      sections = described_class.load("/tmp/fake.pdf")

      expect(sections.size).to eq(1)
      expect(sections.first.text).to eq("Whole-document fallback text, long enough to clear the threshold easily.")
      expect(sections.first.heading).to eq("chunk1 §1")
    end

    it "uses an overridden file_id instead of the path basename" do
      stub_extraction(chunks: [chunk("Long enough chunk text to clear the minimum length threshold for a section.")])

      sections = described_class.load("/tmp/fake.pdf", file_id: "custom-id")

      expect(sections.first.document_id).to start_with("custom-id#")
    end

    it "passes nil frontmatter when Kreuzberg returns no metadata" do
      stub_extraction(chunks: [chunk("Long enough chunk text to clear the minimum length threshold easily.", first_page: 1)])

      sections = described_class.load("/tmp/fake.pdf")

      expect(sections.first.frontmatter).to be_nil
    end

    it "builds a frontmatter hash from PDF title, author, and keywords" do
      kw = instance_double(Kreuzberg::ExtractedKeyword, text: "nlp")
      stub_extraction(
        chunks: [chunk("Long enough chunk text to clear the minimum length threshold easily.", first_page: 1)],
        metadata: { "title" => "Research Paper", "author" => "A. Author", "created" => "2024-01-15" },
        extracted_keywords: [kw]
      )

      section = described_class.load("/tmp/fake.pdf").first
      fm = section.frontmatter

      expect(fm["title"]).to eq("Research Paper")
      expect(fm["author"]).to eq("A. Author")
      expect(fm["tags"]).to include("nlp")
      expect(fm["last updated"]).to be_a(Time)
    end

    it "returns nil frontmatter when metadata hash is empty" do
      stub_extraction(
        chunks: [chunk("Long enough chunk text to clear the minimum length threshold easily.", first_page: 1)],
        metadata: {},
        extracted_keywords: []
      )

      expect(described_class.load("/tmp/fake.pdf").first.frontmatter).to be_nil
    end
  end
end
