# frozen_string_literal: true

module SFL
  module Compiler
    # ImageLoader — pre-processor for image files (.png, .jpg, .jpeg, .webp).
    #
    # Uses a vision-capable LLM (via RubyLLM) to extract a text description
    # of the image, which is then fed into the SFL pipeline as prose. Falls
    # back to a minimal stub (filename + format) if vision is unavailable or
    # the call fails — the artifact is still created with annotation_source
    # "fallback" rather than silently dropped.
    #
    # Returns the same MarkdownLoader::Section shape as MarkdownLoader and
    # PdfLoader so KnowledgeBaseAnalyzer doesn't need loader-specific branches.
    class ImageLoader
      Section = MarkdownLoader::Section

      SUPPORTED_EXTENSIONS = %w[.png .jpg .jpeg .webp].freeze

      VISION_PROMPT = <<~PROMPT.freeze
        Describe the content of this image in plain prose, focusing on:
        - Any visible text, labels, or captions
        - The type of image (diagram, screenshot, photo, chart, etc.)
        - Key concepts or subjects depicted
        - Technical details if this is a diagram or code screenshot
        Write 2-5 sentences. Do not use bullet points.
      PROMPT

      # @param path [String, Pathname]
      # @param file_id [String, nil]
      # @param vision_model [String, nil] RubyLLM model id; nil uses the
      #   configured default. Must support vision input.
      def initialize(path, file_id: nil, vision_model: nil)
        @path        = path.to_s
        @file_id     = file_id || File.basename(@path, ".*")
        @vision_model = vision_model
      end

      # @param path [String]
      # @return [Array<Section>]
      def self.load(path, **)
        new(path, **).sections
      end

      # @return [Array<Section>]
      def sections
        text = describe_image
        return [] if text.nil? || text.strip.empty?

        [Section.new(
          document_id: "#{@file_id}#image",
          file_id:     @file_id,
          heading:     "Image: #{File.basename(@path)}",
          heading_level: 1,
          heading_slug: "image",
          text:,
          byte_range:  nil,
          frontmatter: {
            "content_type" => "image",
            "source_path"  => @path,
            "format"       => File.extname(@path).downcase.delete(".")
          }
        )]
      end

      private

      def describe_image
        chat = @vision_model ? RubyLLM.chat(model: @vision_model) : RubyLLM.chat
        response = chat.ask(VISION_PROMPT, with: { image: @path })
        response.content&.strip
      rescue => e
        warn "[WARN] ImageLoader: vision call failed for #{File.basename(@path)}: #{e.message}"
        fallback_description
      end

      def fallback_description
        ext = File.extname(@path).delete(".").upcase
        size_kb = (File.size(@path) / 1024.0).round(1)
        "#{ext} image file: #{File.basename(@path)} (#{size_kb} KB). Visual content could not be extracted."
      end
    end
  end
end
