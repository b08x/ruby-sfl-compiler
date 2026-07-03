# frozen_string_literal: true

require "inkmark"
require "pragmatic_tokenizer"

module SFL
  module Compiler
    # MarkdownLoader — upstream pre-processor for the two-pass SFL pipeline.
    #
    # Bridges Inkmark's markdown parsing with Pipeline#compile by:
    #   1. Chunking a markdown document into heading-scoped sections via
    #      Inkmark.chunks_by_heading
    #   2. Rendering each section to HTML (Inkmark handles all structural
    #      markdown at the AST level), then stripping HTML tags to get
    #      clean prose — no `**bold**` or `[link](url)` reaching spaCy
    #   3. Dropping fenced code blocks (non-prose; corrupt POS/dep parses)
    #   4. Normalising via PragmaticTokenizer — URL removal, hashtag/mention
    #      stripping, token-level cleanup
    #   5. Emitting structured Section values with document_id encoded as
    #      "#{file_id}##{section_slug}" for section-granular retrieval
    #
    # Usage — feed each section directly into Pipeline#compile:
    #
    #   loader = SFL::Compiler::MarkdownLoader.new("sources/lsd-brain.md")
    #   loader.each_section do |section|
    #     pipeline.compile(section.text, document_id: section.document_id)
    #   end
    #
    # Or collect all sections for batch Pass 1:
    #
    #   sections = SFL::Compiler::MarkdownLoader.load("sources/lsd-brain.md")
    #   sections.each { |s| pipeline.compile_pass_one(s.text, document_id: s.document_id) }
    #
    class MarkdownLoader
      # PragmaticTokenizer options for prose normalisation.
      # :all keeps numbers and punctuation so spaCy sees natural sentence
      # boundaries; remove_urls + clean strip noise that regex used to handle.
      TOKENIZER_OPTIONS = {
        language:    "en",
        remove_urls: true,
        hashtags:    :remove,
        mentions:    :remove,
        clean:       true,
        punctuation: :all,
        numbers:     :all,
        downcase:    false
      }.freeze

      # HTML entities decoded before plain-text extraction.
      HTML_ENTITIES = {
        "&amp;"  => "&",
        "&lt;"   => "<",
        "&gt;"   => ">",
        "&quot;" => '"',
        "&#39;"  => "'",
        "&nbsp;" => " "
      }.freeze

      # Punctuation tokens that attach to the preceding word (no leading space).
      CLOSING_PUNCT = %w[. , ! ? ; : ) \] } … -- -].to_set.freeze

      # Structured section value returned by each_section / load.
      Section = Struct.new(
        :document_id,    # "#{file_id}##{heading_slug}" — e.g. "lsd-brain#the-tldr"
        :file_id,        # base filename without extension
        :heading,        # heading text (nil for preamble before first heading)
        :heading_level,  # Integer 1-6 (nil for preamble)
        :heading_slug,   # URL-safe id from Inkmark (nil for preamble)
        :text,           # clean plain-prose text ready for spaCy
        :byte_range,     # Range into original source (nil for preamble)
        :frontmatter,    # Hash parsed from YAML frontmatter (nil if absent)
        keyword_init: true
      )

      # @param path [String, Pathname] Path to the markdown file
      # @param file_id [String, nil] Override the auto-derived file identifier.
      #   Defaults to the filename stem (e.g. "lsd-brain-network-collapse").
      # @param skip_empty [Boolean] Drop sections whose cleaned text is blank.
      # @param min_length [Integer] Minimum character length of cleaned text
      #   to emit. Filters out stub sections with only a heading and no prose.
      def initialize(path, file_id: nil, skip_empty: true, min_length: 40)
        @path = path.to_s
        @source = File.read(@path, encoding: "utf-8")
        @file_id = file_id || File.basename(@path, ".*")
        @skip_empty = skip_empty
        @min_length = min_length
      end

      # Enumerate sections.
      # @yield [Section]
      def each_section
        return enum_for(:each_section) unless block_given?

        sections_from_source.each do |section|
          next if @skip_empty && section.text.strip.empty?
          next if section.text.strip.length < @min_length

          yield section
        end
      end

      # Return all sections as an array.
      # @return [Array<Section>]
      def sections
        each_section.to_a
      end

      # Convenience class method.
      # @param path [String] Path to markdown file
      # @param kwargs passed to #initialize
      # @return [Array<Section>]
      def self.load(path, **kwargs)
        new(path, **kwargs).sections
      end

      private

      def sections_from_source
        # Parse YAML frontmatter before stripping it — Inkmark mis-parses
        # the `---` block as a setext H2, collapsing the whole document.
        fm = parse_frontmatter(@source)
        body_source = @source.sub(/\A---\n.*?\n---\n?/m, "")

        # Inkmark.chunks_by_heading already emits a heading: nil chunk for
        # any content before the first ATX heading — including the entire
        # body when a document has no headings at all. A previous version
        # of this method also hand-extracted that same span via a separate
        # #extract_preamble regex and emitted it as a second section,
        # duplicating every document's preamble verbatim: confirmed live
        # (a headless conversation transcript produced two identical
        # ~13k-char sections, doubling Pass 1/2 cost and corrupting
        # per-document aggregates — topic modeling, quality scores — with
        # an exact-duplicate document for every file with any pre-heading
        # prose, not just fully headless ones).
        Inkmark.chunks_by_heading(body_source).map do |chunk|
          preamble = chunk[:heading].nil?
          Section.new(
            document_id: "#{@file_id}##{preamble ? "preamble" : chunk[:id]}",
            file_id: @file_id,
            heading: chunk[:heading],
            heading_level: preamble ? nil : chunk[:level],
            heading_slug: chunk[:id],
            text: clean_text(chunk[:content]),
            byte_range: chunk[:byte_range],
            frontmatter: fm
          )
        end
      end

      def parse_frontmatter(source)
        match = source.match(/\A---\n(.*?)\n---\n?/m)
        return nil unless match

        require "yaml"
        YAML.safe_load(match[1], permitted_classes: [Time, Date, Symbol])
      rescue StandardError
        nil
      end

      # Render markdown to clean prose using Inkmark's AST pipeline and
      # PragmaticTokenizer for token-level normalisation.
      #
      # Flow:
      #   markdown → Inkmark.to_html (strips all structural syntax at AST level)
      #     → drop <pre><code> blocks (non-prose)
      #     → strip HTML tags + decode entities
      #     → PragmaticTokenizer (remove URLs, hashtags, mentions, clean noise)
      #     → rejoin tokens into prose string
      def clean_text(markdown)
        return "" if markdown.nil? || markdown.strip.empty?

        result = markdown.dup
        result.sub!(/\A---\n.*?\n---\n/m, "")
        return "" if result.strip.empty?

        # Inkmark renders to HTML — all markdown structure (bold, italic,
        # links, images, list markers, heading markers) handled at AST level.
        html = Inkmark.new(result, options: { syntax_highlight: false }).to_html

        # Drop fenced code blocks — identifiers corrupt POS/dependency parses.
        html.gsub!(/<pre><code[^>]*>.*?<\/code><\/pre>/m, " ")

        # Strip remaining HTML tags.
        prose = html.gsub(/<[^>]+>/, " ")

        # Decode HTML entities.
        HTML_ENTITIES.each { |entity, char| prose.gsub!(entity, char) }
        prose.gsub!(/&[a-z#0-9]+;/, " ")

        # Collapse whitespace, split into paragraphs.
        paragraphs = prose.gsub(/\t/, " ").split(/\n/).map(&:strip).reject(&:empty?)

        return "" if paragraphs.empty?

        # Normalise each paragraph through PragmaticTokenizer.
        cleaned = paragraphs.map { |para| normalise_paragraph(para) }.reject(&:empty?)

        cleaned.join("\n\n")
      end

      # Tokenise a prose paragraph and rejoin with natural spacing.
      # PragmaticTokenizer separates punctuation as distinct tokens;
      # CLOSING_PUNCT tokens reattach without a leading space.
      def normalise_paragraph(para)
        tokens = PragmaticTokenizer::Tokenizer.new(TOKENIZER_OPTIONS).tokenize(para)
        return "" if tokens.empty?

        tokens.each_with_object([]) do |tok, buf|
          if buf.empty? || CLOSING_PUNCT.include?(tok)
            buf << tok
          else
            buf << " #{tok}"
          end
        end.join.strip
      end
    end
  end
end
