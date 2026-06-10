# frozen_string_literal: true

require "ruby-spacy"
require "journald/logger"

module SFL
  module Compiler
    # Pass One: Syntactic Engine
    # Transforms raw text into dependency-parsed clause structures.
    # Uses ruby-spacy (via PyCall) for tokenization, POS tagging,
    # dependency parsing, and sentence boundary detection.
    #
    # Single-pass design: one `nlp.read()` call per section, using spaCy's
    # built-in sentence segmentation (`doc.sents`) rather than a separate
    # PragmaticSegmenter pass. This avoids N PyCall round-trips per section
    # (one per sentence) and instead pays exactly one round-trip per section.
    #
    # Output: Array of Types::SyntacticClause structs with full token-level
    # annotations — the "raw material" for Ideational extraction.
    class PassOneEngine
      def initialize(model: nil)
        @model = model || SFL::Compiler.config.spacy_model
        @nlp = Spacy::Language.new(@model)
        @logger = Journald::Logger.new("sfl-compiler-pass-one")
      end

      # Process raw text into syntactic clauses.
      # One spaCy read per section; sentence boundaries from doc.sents.
      #
      # @param text [String] Raw input text (a MarkdownLoader section)
      # @param document_id [String, nil] Optional source document identifier
      # @return [Array<Types::SyntacticClause>]
      def process(text, document_id: nil)
        return [] if text.nil? || text.strip.empty?

        start_time = Time.now
        correlation_id = SecureRandom.uuid

        @logger.send_message(
          message: "pass_one_started",
          priority: Journald::LOG_INFO,
          correlation_id: correlation_id,
          document_id: document_id,
          text_length: text.length,
          model: @model
        )

        # Single read — spaCy parses the full section text at once.
        # Sentence segmentation is a by-product of dependency parsing.
        doc = @nlp.read(text)

        clauses = []
        sent_idx = 0

        doc.sents.each do |sent|
          sent_text = sent.text.strip
          next if sent_text.empty?

          tokens = extract_tokens_from_span(sent)
          next if tokens.empty?

          root_idx = find_root_index(tokens)

          clauses << Types::SyntacticClause.new(
            id: SecureRandom.uuid,
            text: sent_text,
            tokens: tokens,
            root_index: root_idx,
            sentence_index: sent_idx,
            document_id: document_id
          )

          sent_idx += 1
        end

        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "pass_one_completed",
          priority: Journald::LOG_INFO,
          correlation_id: correlation_id,
          document_id: document_id,
          clause_count: clauses.length,
          token_count: clauses.sum { |c| c.tokens.length },
          latency_ms: elapsed_ms
        )

        clauses
      rescue StandardError => e
        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "pass_one_failed",
          priority: Journald::LOG_ERR,
          correlation_id: correlation_id,
          document_id: document_id,
          error_class: e.class.name,
          error_message: e.message,
          latency_ms: elapsed_ms
        )

        raise PassOneError, "Syntactic extraction failed: #{e.message}"
      end

      private

      # Extract SyntacticToken structs from a spaCy sentence span.
      # Token indices are sentence-local (0-based within the sentence),
      # matching the root_index stored on SyntacticClause.
      def extract_tokens_from_span(sent)
        tokens = []
        # Build a text→local_idx map for head resolution within this sentence.
        local_idx = {}
        raw = []
        sent.each do |token|
          next if token.text.strip.empty?
          local_idx[token.text] ||= raw.length
          raw << token
        end

        raw.each_with_index do |token, idx|
          head_idx = if token.head.nil? || token.head.text == token.text
                       -1  # ROOT
                     else
                       local_idx[token.head.text] || -1
                     end

          morphology = begin
            token.morphology.to_h
          rescue StandardError
            {}
          end

          tokens << Types::SyntacticToken.new(
            text: token.text,
            lemma: token.respond_to?(:lemma_) ? token.lemma_ : token.text.downcase,
            pos: token.pos || "X",
            tag: token.tag || "X",
            dep: token.dep || "dep",
            head_index: head_idx,
            morphology: morphology,
            index: idx
          )
        end

        tokens
      end

      def find_root_index(tokens)
        tokens.each_with_index do |token, idx|
          return idx if token.dep == "ROOT"
        end
        0  # Fallback to first token
      end
    end
  end
end
