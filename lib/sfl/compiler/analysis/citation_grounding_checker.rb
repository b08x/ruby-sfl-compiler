# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Post-generation citation grounding checker.
      #
      # Verifies that claims in a narrative are anchored to source clauses via
      # citation markers. A claim is grounded when it contains at least one
      # `[clause-id]` marker that (a) resolves to a known clause and (b) shares
      # two or more content words with that clause's text.
      #
      # This is the Crab role: constraint enforcer after generation, not during.
      class CitationGroundingChecker
        # Matches any [marker] in text; the captured group is the raw ref string.
        CITATION_RE = /\[([^\]]+)\]/.freeze

        # Minimum shared content-word count to consider a sentence semantically
        # supported by its cited clause.
        MIN_SHARED_WORDS = 2

        # Common function words excluded from keyword overlap scoring.
        STOP_WORDS = %w[
          the and but for are was were has have had
          that this with from into about over also not
          can all its they their them there what when
          where who which how any more one two does did
          will would could should been being just then
          such each only than those these very well
        ].freeze

        # @param narrative_text [String] full narrative prose (all sections joined)
        # @param source_clauses [Array<Types::AnnotatedClause | Hash>]
        #   each element must respond to [:id]/[:text] (Hash) or .id/.text (Struct)
        # @return [Hash] {
        #   grounded:   Array<{sentence:, citations:}>,
        #   ungrounded: Array<{sentence:, citations:, reason:}>,
        #   coverage:   Float (0.0–1.0)
        # }
        def check(narrative_text, source_clauses)
          index     = build_index(source_clauses)
          sentences = extract_sentences(narrative_text)

          grounded   = []
          ungrounded = []

          sentences.each do |sentence|
            citations = extract_citations(sentence)

            if citations.empty?
              ungrounded << { sentence:, citations: [], reason: "no citation marker" }
              next
            end

            missing_ids = citations.reject { |ref| resolve(ref, index) }
            if missing_ids.any?
              ungrounded << { sentence:, citations:,
                              reason: "clause not found: #{missing_ids.join(', ')}" }
              next
            end

            weak = citations.reject { |ref| keyword_match?(sentence, resolve(ref, index)) }
            if weak.any?
              ungrounded << { sentence:, citations:,
                              reason: "no keyword overlap with cited clause(s)" }
            else
              grounded << { sentence:, citations: }
            end
          end

          total    = sentences.size
          coverage = total.zero? ? 0.0 : grounded.size.to_f / total

          { grounded:, ungrounded:, coverage: }
        end

        private

        # Build a flat id→text lookup supporting:
        #   - exact UUID or slug match:  index["abc-123"] → "clause text"
        #   - compound doc:id match:     index["doc-1:abc-123"] → "clause text"
        def build_index(clauses)
          clauses.each_with_object({}) do |clause, idx|
            id   = clause.is_a?(Hash) ? (clause[:id]   || clause["id"])   : clause.id
            text = clause.is_a?(Hash) ? (clause[:text] || clause["text"]) : clause.text
            next unless id && text

            idx[id.to_s]      = text.to_s
            doc_id = clause.is_a?(Hash) ? (clause[:document_id] || clause["document_id"]) : clause.document_id
            idx["#{doc_id}:#{id}"] = text.to_s if doc_id
          end
        end

        # Split prose into individual sentences on sentence-terminal punctuation.
        def extract_sentences(text)
          text.scan(/[^.!?\n]+[.!?]+/).map(&:strip).reject(&:empty?)
        end

        # Return all citation ref strings found in a sentence.
        def extract_citations(sentence)
          sentence.scan(CITATION_RE).flatten
        end

        # Resolve a citation reference against the index, trying:
        #   1. exact key,  2. key with any known doc prefix stripped.
        def resolve(ref, index)
          return index[ref] if index.key?(ref)

          # compound "doc-id:clause-id" — try the clause-id suffix
          if ref.include?(":")
            suffix = ref.split(":", 2).last
            return index[suffix] if index.key?(suffix)
          end

          nil
        end

        def keyword_match?(sentence, clause_text)
          return false if clause_text.nil? || clause_text.empty?

          shared = content_words(sentence) & content_words(clause_text)
          shared.size >= MIN_SHARED_WORDS
        end

        def content_words(text)
          text.downcase.scan(/\b[a-z]{3,}\b/) - STOP_WORDS
        end
      end
    end
  end
end
