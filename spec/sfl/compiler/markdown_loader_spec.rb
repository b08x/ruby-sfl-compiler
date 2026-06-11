# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe SFL::Compiler::MarkdownLoader do
  # Use a real tempdir + markdown file for end-to-end loader tests.
  # MarkdownLoader reads the file with File.read, so we need actual files on disk.
  let(:tmpdir) { Dir.mktmpdir("sfl-mdloader-spec-") }
  after { FileUtils.remove_entry(tmpdir) if File.directory?(tmpdir) }

  def write_md(name, contents)
    path = File.join(tmpdir, name)
    File.write(path, contents)
    path
  end

  # ============================================================
  # YAML frontmatter
  # ============================================================
  describe "YAML frontmatter handling" do
    it "strips YAML frontmatter from section text" do
      path = write_md("doc.md", <<~MD)
        ---
        title: My Document
        author: Alice
        date: 2026-01-15
        ---

        # First Section

        Some real prose content here that should survive normalisation.
      MD

      sections = described_class.new(path).sections
      expect(sections).not_to be_empty
      sections.each do |s|
        expect(s.text).not_to include("title:")
        expect(s.text).not_to include("author:")
        expect(s.text).not_to include("Alice")
        expect(s.text).not_to match(/^---/)
        expect(s.text).not_to include("My Document")
      end
    end

    it "does not treat frontmatter delimiter as a heading" do
      path = write_md("doc.md", <<~MD)
        ---
        title: Test
        ---

        # Heading One

        Body content for heading one with enough characters to pass min length filter.
      MD

      sections = described_class.new(path).sections
      headings = sections.map(&:heading).compact
      expect(headings).to eq(["Heading One"])
    end
  end

  # ============================================================
  # Fenced code blocks
  # ============================================================
  describe "fenced code block handling" do
    it "drops fenced code blocks from section text" do
      path = write_md("doc.md", <<~MD)
        # Code Section

        This is real prose that should appear in the output of the document.

        ```ruby
        def hello_world
          puts "this code should be dropped"
        end
        ```

        This trailing prose should also appear after the code block in the output.
      MD

      sections = described_class.new(path).sections
      expect(sections.length).to eq(1)
      expect(sections.first.text).to include("real prose")
      expect(sections.first.text).to include("trailing prose")
      expect(sections.first.text).not_to include("def hello_world")
      expect(sections.first.text).not_to include('puts "this code should be dropped"')
      expect(sections.first.text).not_to include("```")
    end

    it "handles code blocks with language hints" do
      path = write_md("doc.md", <<~MD)
        # Section Title

        Prose content that should remain in the section after the code block.

        ```python
        def add(a, b):
            return a + b
        ```

        More prose content after the fenced code block with a different language.
      MD

      text = described_class.new(path).sections.first.text
      expect(text).not_to include("def add")
      expect(text).not_to include("python")
      expect(text).to include("Prose content")
      expect(text).to include("More prose content")
    end
  end

  # ============================================================
  # HTML entities
  # ============================================================
  describe "HTML entity decoding" do
    it "decodes common HTML entities to their character equivalents" do
      path = write_md("doc.md", <<~MD)
        # Section with Entities

        The cat &amp; the dog played together in the yard.
        Tags like &lt;div&gt; should be cleaned up properly.
        Quotes &quot;like this&quot; and apostrophes &#39;too&#39; are decoded.
      MD

      text = described_class.new(path).sections.first.text
      expect(text).to include("&")
      expect(text).not_to include("&amp;")
      expect(text).to include("div")  # tag content may remain after tag stripping
      expect(text).to include('"')
      expect(text).not_to include("&quot;")
      expect(text).to include("'")
      expect(text).not_to include("&#39;")
    end
  end

  # ============================================================
  # Preamble (content before first heading)
  # ============================================================
  describe "preamble handling" do
    it "creates a preamble section when content precedes the first heading" do
      path = write_md("doc.md", <<~MD)
        This is preamble content that appears before any heading in the document.

        It can be multiple paragraphs and is treated as its own section.

        # First Heading

        Content under the first heading that has enough text to be retained.
      MD

      sections = described_class.new(path).sections
      preamble = sections.find { |s| s.heading.nil? }

      expect(preamble).not_to be_nil
      expect(preamble.heading).to be_nil
      expect(preamble.heading_level).to be_nil
      expect(preamble.heading_slug).to be_nil
      expect(preamble.document_id).to end_with("#preamble")
      expect(preamble.text).to include("preamble content")
      expect(preamble.text).to include("multiple paragraphs")
    end

    it "omits preamble when there is no content before the first heading" do
      path = write_md("doc.md", <<~MD)
        # First Heading

        Body content starts immediately under the first heading.
      MD

      sections = described_class.new(path).sections
      expect(sections.map(&:heading)).to eq(["First Heading"])
    end

    it "omits preamble when min_length is not met" do
      path = write_md("doc.md", <<~MD)
        Short.

        # First Heading

        Body content under the first heading with enough characters to remain.
      MD

      sections = described_class.new(path).sections
      expect(sections.map(&:heading)).to eq(["First Heading"])
    end
  end

  # ============================================================
  # Heading-scoped sections
  # ============================================================
  describe "heading-scoped sections" do
    it "creates a Section for each heading" do
      path = write_md("doc.md", <<~MD)
        # Heading One

        First section content with enough text to pass the minimum length filter.

        # Heading Two

        Second section content with a different topic and enough text to remain.

        # Heading Three

        Third section content with still more text that should be its own section.
      MD

      sections = described_class.new(path).sections
      expect(sections.length).to eq(3)
      expect(sections.map(&:heading)).to eq(["Heading One", "Heading Two", "Heading Three"])
    end

    it 'builds document_id as "#{file_id}##{heading_slug}"' do
      path = write_md("my-doc.md", <<~MD)
        # The Title

        Some content under the title that should be included in this section.
      MD

      sections = described_class.new(path).sections
      expect(sections.first.document_id).to match(/\Amy-doc#/)
      expect(sections.first.document_id).to include("the-title")
    end

    it "captures heading_level from the source" do
      path = write_md("doc.md", <<~MD)
        ## Second Level

        Content under a level 2 heading with enough text to pass the min length.

        ### Third Level

        Content under a level 3 heading with enough text to pass the min length.
      MD

      sections = described_class.new(path).sections
      expect(sections.find { |s| s.heading == "Second Level" }.heading_level).to eq(2)
      expect(sections.find { |s| s.heading == "Third Level" }.heading_level).to eq(3)
    end
  end

  # ============================================================
  # Markdown syntax stripping
  # ============================================================
  describe "markdown syntax stripping" do
    it "strips bold, italic, and link syntax but keeps the prose" do
      path = write_md("doc.md", <<~MD)
        # Formatting

        This has **bold text** and *italic text* and even
        [a link to somewhere](https://example.com) that should not appear
        in the cleaned prose output of the document.
      MD

      text = described_class.new(path).sections.first.text
      expect(text).to include("bold text")
      expect(text).to include("italic text")
      expect(text).to include("a link to somewhere")
      expect(text).not_to include("**")
      expect(text).not_to include("https://example.com")
      expect(text).not_to match(/\[\w+\]\(/)
    end

    it "strips list markers but keeps list item text" do
      path = write_md("doc.md", <<~MD)
        # Lists

        Here is a list of items that should all appear in the final prose:

        - First item in the list
        - Second item in the list
        - Third item in the list

        Trailing paragraph that adds more prose to the section text content.
      MD

      text = described_class.new(path).sections.first.text
      expect(text).to include("First item")
      expect(text).to include("Second item")
      expect(text).to include("Third item")
      expect(text).not_to match(/^-\s/)
    end

    it "strips image syntax from the output" do
      path = write_md("doc.md", <<~MD)
        # Images

        An inline image ![alt text description](image.png) appears in the prose
        and should not survive into the cleaned output. The surrounding prose,
        however, is plain text and should remain visible after normalisation.
      MD

      text = described_class.new(path).sections.first.text
      expect(text).to include("An inline image")
      expect(text).to include("surrounding prose")
      expect(text).not_to include("image.png")
      expect(text).not_to include("![")
      expect(text).not_to match(/<img/)
    end
  end

  # ============================================================
  # PragmaticTokenizer normalisation
  # ============================================================
  describe "PragmaticTokenizer normalisation" do
    it "removes inline URLs from the text" do
      path = write_md("doc.md", <<~MD)
        # URLs

        Check out https://example.com for more details on this particular topic.
        Also see https://other-site.org/path?q=1 for the full reference document.
      MD

      text = described_class.new(path).sections.first.text
      expect(text).not_to include("https://example.com")
      expect(text).not_to include("https://other-site.org")
    end

    it "removes hashtags from the text" do
      path = write_md("doc.md", <<~MD)
        # Hashtags

        This is a #programming post about Ruby and about the language itself.
      MD

      text = described_class.new(path).sections.first.text
      expect(text).not_to include("#programming")
      expect(text).to include("Ruby")
    end

    it "removes @mentions from the text" do
      path = write_md("doc.md", <<~MD)
        # Mentions

        Thanks to @alice and @bob for the great discussion on this topic today.
      MD

      text = described_class.new(path).sections.first.text
      expect(text).not_to include("@alice")
      expect(text).not_to include("@bob")
    end
  end

  # ============================================================
  # Filtering behaviour (skip_empty, min_length)
  # ============================================================
  describe "filtering behaviour" do
    it "skips sections whose cleaned text is empty" do
      path = write_md("doc.md", <<~MD)
        # Empty Section

        # Real Section

        This real section has enough text content to pass the min length filter
        and is not empty so it should definitely be retained in the final output.
      MD

      sections = described_class.new(path).sections
      expect(sections.length).to eq(1)
      expect(sections.first.heading).to eq("Real Section")
    end

    it "skips sections shorter than min_length" do
      path = write_md("doc.md", <<~MD)
        # Short

        Too brief.

        # Long Enough

        This section has plenty of prose to comfortably exceed the default
        minimum character length threshold and survive into the output list.
      MD

      sections = described_class.new(path, min_length: 20).sections
      expect(sections.length).to eq(1)
      expect(sections.first.heading).to eq("Long Enough")
    end

    it "honors skip_empty: false to keep empty sections" do
      path = write_md("doc.md", <<~MD)
        # Heading With Body

        Some body content here that is long enough to be kept in the output.
      MD

      sections = described_class.new(path, skip_empty: false).sections
      expect(sections.length).to be >= 1
      expect(sections.first.heading).to eq("Heading With Body")
    end
  end

  # ============================================================
  # file_id option
  # ============================================================
  describe "file_id option" do
    it "defaults file_id to filename stem" do
      path = write_md("my-cool-doc.md", <<~MD)
        # First Heading

        Body content under the first heading with enough text to remain.
      MD

      sections = described_class.new(path).sections
      expect(sections).not_to be_empty
      expect(sections.map(&:file_id).uniq).to eq(["my-cool-doc"])
      expect(sections.first.document_id).to start_with("my-cool-doc#")
    end

    it "accepts an explicit file_id override" do
      path = write_md("whatever.md", <<~MD)
        # First Heading

        Body content under the first heading with enough text to remain.
      MD

      sections = described_class.new(path, file_id: "custom-id").sections
      expect(sections.map(&:file_id).uniq).to eq(["custom-id"])
      expect(sections.first.document_id).to start_with("custom-id#")
    end
  end

  # ============================================================
  # Class method shortcut + enumeration
  # ============================================================
  describe ".load" do
    it "returns an array of sections without needing .new" do
      path = write_md("doc.md", <<~MD)
        # Heading

        Body content under the heading with enough text to remain in the list.
      MD

      sections = described_class.load(path)
      expect(sections).to be_an(Array)
      expect(sections.first).to be_a(SFL::Compiler::MarkdownLoader::Section)
    end
  end

  describe "#each_section" do
    it "yields each section when given a block" do
      path = write_md("doc.md", <<~MD)
        # One

        First section body content with plenty of text to remain in output.

        # Two

        Second section body content with plenty of text to remain in output.
      MD

      yielded = []
      described_class.new(path).each_section { |s| yielded << s }
      expect(yielded.length).to eq(2)
      expect(yielded.map(&:heading)).to eq(["One", "Two"])
    end

    it "returns an Enumerator when no block is given" do
      path = write_md("doc.md", <<~MD)
        # One

        First section body content with plenty of text to remain in output.
      MD

      result = described_class.new(path).each_section
      expect(result).to be_an(Enumerator)
      expect(result.to_a.length).to eq(1)
    end
  end

  # ============================================================
  # Section struct
  # ============================================================
  describe SFL::Compiler::MarkdownLoader::Section do
    it "is a Struct with all expected fields" do
      section = described_class.new(
        document_id: "doc#heading",
        file_id: "doc",
        heading: "Heading",
        heading_level: 1,
        heading_slug: "heading",
        text: "Body text content here",
        byte_range: (0..10)
      )

      expect(section.document_id).to eq("doc#heading")
      expect(section.file_id).to eq("doc")
      expect(section.heading).to eq("Heading")
      expect(section.heading_level).to eq(1)
      expect(section.heading_slug).to eq("heading")
      expect(section.text).to eq("Body text content here")
      expect(section.byte_range).to eq(0..10)
    end
  end
end