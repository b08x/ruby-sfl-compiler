# frozen_string_literal: true

require "json"

module SFL
  module Compiler
    # CanvasLoader — Obsidian .canvas files (JSON node-graph: nodes have a
    # type of group/file/text/link, positioned on an x/y/width/height
    # plane, connected by edges).
    #
    # Only `text` nodes carry prose worth SFL annotation. `group` nodes are
    # pure layout (a label, no body). `file` nodes reference another vault
    # file by path — deliberately not resolved/inlined here: that file is
    # its own document and gets its own artifact on KnowledgeBaseAnalyzer's
    # own pass over the vault: inlining it here would duplicate its clauses
    # under two document_ids. `link` nodes (bare URLs) carry no local prose
    # either. Emits the same MarkdownLoader::Section shape as
    # PdfLoader/MarkdownLoader so KnowledgeBaseAnalyzer's loader dispatch
    # doesn't need to know which loader produced a given section.
    class CanvasLoader
      Section = MarkdownLoader::Section

      # @param path [String, Pathname]
      # @param file_id [String, nil] Override the auto-derived file identifier.
      # @param skip_empty [Boolean] Drop text nodes whose content is blank/too short.
      # @param min_length [Integer] Minimum character length to emit a section.
      def initialize(path, file_id: nil, skip_empty: true, min_length: 40)
        @path = path.to_s
        @file_id = file_id || File.basename(@path, ".*")
        @skip_empty = skip_empty
        @min_length = min_length
      end

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

        text_nodes.each_with_index do |node, index|
          text = node[:text].to_s.strip
          next unless emit?(text)

          yield build_section(text, node[:id] || "node#{index + 1}")
        end
      end

      private def text_nodes
        canvas = JSON.parse(File.read(@path, encoding: "utf-8"), symbolize_names: true)
        Array(canvas[:nodes]).select { |node| node[:type] == "text" }
      end

      private def emit?(text) = !@skip_empty || text.length >= @min_length

      private def build_section(text, slug)
        Section.new(
          document_id: "#{@file_id}##{slug}",
          file_id: @file_id,
          heading: "canvas node #{slug}",
          heading_level: 1,
          heading_slug: slug,
          text:,
          byte_range: nil,
          frontmatter: nil
        )
      end
    end
  end
end
