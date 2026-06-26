# frozen_string_literal: true

require "kreuzberg"

module SFL
  module Compiler
    # PdfLoader — upstream pre-processor for PDFs, paralleling MarkdownLoader.
    #
    # PDFs have no heading structure to chunk by, and (verified live
    # against the installed kreuzberg 4.9.9) extracted page text loses
    # blank-line paragraph breaks entirely — every wrapped line and every
    # true paragraph boundary both collapse to the same "\r\n", so a
    # blank-line split heuristic (the natural MarkdownLoader analogue)
    # silently produces one giant chunk per page on real PDFs.
    #
    # Kreuzberg's own Config::Chunking is real and sentence-boundary-aware
    # (confirmed live: never splits mid-sentence) and anchors each chunk
    # to first_page/last_page, so sections are derived from that instead
    # of a paragraph-detection heuristic that doesn't survive extraction.
    # Emits the same MarkdownLoader::Section shape so DocumentationAnalyzer
    # doesn't need to know which loader produced a given section.
    class PdfLoader
      Section = MarkdownLoader::Section

      # ~paragraph-sized; no overlap so clauses aren't extracted twice
      # across adjacent chunks (overlap exists for embedding/retrieval
      # use cases, not clause-extraction).
      DEFAULT_CHUNKING = Kreuzberg::Config::Chunking.new(max_chars: 1000, max_overlap: 0).freeze

      # @param path [String, Pathname]
      # @param file_id [String, nil] Override the auto-derived file identifier.
      # @param skip_empty [Boolean] Drop chunks whose cleaned text is blank.
      # @param min_length [Integer] Minimum character length of cleaned text to emit.
      def initialize(path, file_id: nil, skip_empty: true, min_length: 40)
        @path = path.to_s
        @file_id = file_id || File.basename(@path, ".*")
        @skip_empty = skip_empty
        @min_length = min_length
      end

      # @param path [String, Pathname]
      # @return [Array<Section>]
      def self.load(path, **)
        new(path, **).to_a
      end

      # @return [Array<Section>]
      def to_a
        each_section.to_a
      end

      # @yield [Section]
      def each_section
        return to_enum(:each_section) unless block_given?

        config = Kreuzberg::Config::Extraction.new(chunking: DEFAULT_CHUNKING)
        result = Kreuzberg.extract_file_sync(path: @path, config:)
        fm = pdf_frontmatter(result)

        chunks = result.chunks
        if chunks.nil? || chunks.empty?
          chunks = [
            Kreuzberg::Result::Chunk.new(result.content, nil, nil, nil, 0, 1, nil, nil, nil, nil),
          ]
        end

        chunks.each_with_index do |chunk, index|
          cleaned = chunk.content.strip
          next if @skip_empty && cleaned.length < @min_length

          yield build_section(cleaned, chunk:, index:, frontmatter: fm)
        end
      end

      private def build_section(text, chunk:, index:, frontmatter: nil)
        label = chunk.first_page ? "p#{chunk.first_page}" : "chunk#{index + 1}"
        heading = "#{label} §#{index + 1}"
        slug = "#{label}-#{index + 1}"

        Section.new(
          document_id: "#{@file_id}##{slug}",
          file_id: @file_id,
          heading:,
          heading_level: 1,
          heading_slug: slug,
          text:,
          byte_range: nil,
          frontmatter:
        )
      end

      # Builds a frontmatter hash from Kreuzberg's document-level metadata.
      # Returns nil when the PDF carries no extractable metadata — avoids
      # polluting downstream classifiers with empty hashes.
      private def pdf_frontmatter(result)
        meta = result.metadata
        return nil unless meta.is_a?(Hash)

        title   = non_blank(meta.dig("title"))
        author  = non_blank(meta.dig("author"))
        created = meta.dig("created") || meta.dig("creation_date")
        kw_tags = result.extracted_keywords&.map(&:text)&.compact || []

        return nil if title.nil? && author.nil? && created.nil? && kw_tags.empty?

        fm = {}
        fm["title"]        = title             if title
        fm["author"]       = author            if author
        fm["tags"]         = kw_tags           unless kw_tags.empty?
        fm["last updated"] = parse_pdf_date(created) if created
        fm
      end

      private def non_blank(val)
        str = val.to_s.strip
        str.empty? ? nil : str
      end

      private def parse_pdf_date(date_str)
        require "time"
        Time.parse(date_str.to_s)
      rescue ArgumentError, TypeError
        nil
      end
    end
  end
end
