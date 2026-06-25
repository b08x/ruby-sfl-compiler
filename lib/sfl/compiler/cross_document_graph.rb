# frozen_string_literal: true

module SFL
  module Compiler
    # Merges multiple per-document QuestionGraphs into one cross-document
    # graph, auto-detecting new derived questions that only make sense
    # once ≥2 documents are compared — e.g. "does the modality finding
    # hold across doc types?" is not askable from either document alone.
    #
    # Each input graph's question ids are namespaced (doc0.modality,
    # doc1.modality, ...) before merging, since two unrelated documents
    # both having a :modality axiom would otherwise collide in the
    # combined QuestionGraph.
    #
    # Scope note: requirement #4 in this card ("auto-create child cards
    # for follow-up analysis") is NOT implemented as a live kanban API
    # call from inside this class — a Ruby gem's library code reaching
    # out to a development-board MCP server has no place at runtime.
    # #deferred_questions returns the same {id:, text:, dependencies:}
    # shape QuestionGraph itself takes as input, which is exactly what a
    # caller (CLI command, orchestration script) needs to turn into
    # cards — the integration point exists, the side effect doesn't.
    class CrossDocumentGraph
      # Minimum number of documents asserting the same finding before a
      # numeric divergence between them is worth flagging for
      # reconciliation, rather than treated as expected per-document
      # noise (also requires ≥3 documents per the card's own spec).
      RECONCILIATION_THRESHOLD = 0.3

      # @param sprint_graphs [Array<QuestionGraph>] one per document
      # @param findings [Array<Hash{Symbol=>Numeric}>, nil] parallel to
      #   sprint_graphs — numeric finding values per canonical question
      #   id (e.g. { modality: 0.8 }). Optional: structural aggregation
      #   (requirement #2) works without it; only reconciliation
      #   detection (requirement #5c) needs real values to compare.
      # @return [CrossDocumentGraph]
      def self.aggregate(sprint_graphs, findings: nil)
        new(sprint_graphs, findings).tap(&:aggregate)
      end

      def initialize(sprint_graphs, findings = nil)
        @sprint_graphs = sprint_graphs
        @findings = findings || Array.new(sprint_graphs.size) { {} }
      end

      # @return [self]
      def aggregate
        @deferred_questions = cross_document_questions
        @questions = namespaced_questions + @deferred_questions
        @graph = QuestionGraph.new(@questions)
        self
      end

      # @return [QuestionGraph] the merged cross-document graph
      attr_reader :graph

      # @return [Array<Hash>] the new questions that only exist because
      #   ≥2 documents were compared — these couldn't be answered from
      #   any single document's own analysis.
      attr_reader :deferred_questions

      private def namespaced_questions
        @sprint_graphs.each_with_index.flat_map do |graph, doc_index|
          graph.questions.values.map do |question|
            {
              id: namespaced_id(doc_index, question.fetch(:id)),
              text: question.fetch(:text),
              dependencies: question.fetch(:dependencies, []).map { |dep| namespaced_id(doc_index, dep) },
            }
          end
        end
      end

      private def namespaced_id(doc_index, id)
        :"doc#{doc_index}.#{id}"
      end

      private def cross_document_questions
        shared_question_ids.flat_map do |canonical_id|
          doc_indices = doc_indices_asking(canonical_id)
          [consistency_question(canonical_id, doc_indices), *reconciliation_question(canonical_id, doc_indices)]
        end
      end

      # Question ids asked by ≥2 documents — the minimum needed for any
      # cross-document comparison to mean anything (requirement #2).
      private def shared_question_ids
        counts = Hash.new(0)
        @sprint_graphs.each { |graph| graph.questions.each_key { |id| counts[id] += 1 } }
        counts.select { |_id, count| count >= 2 }.keys
      end

      private def doc_indices_asking(canonical_id)
        @sprint_graphs.each_index.select { |i| @sprint_graphs[i].questions.key?(canonical_id) }
      end

      private def consistency_question(canonical_id, doc_indices)
        {
          id: :"cross_doc_#{canonical_id}_consistency",
          text: "Does the #{canonical_id} finding hold across documents?",
          dependencies: doc_indices.map { |i| namespaced_id(i, canonical_id) },
        }
      end

      # Requirement #5c: ≥3 documents asking the same question, each
      # with a known numeric finding, whose values disagree by more
      # than RECONCILIATION_THRESHOLD.
      private def reconciliation_question(canonical_id, doc_indices)
        return [] if doc_indices.size < 3

        values = doc_indices.filter_map { |i| @findings[i]&.[](canonical_id) }
        return [] if values.size < 3 || (values.max - values.min) <= RECONCILIATION_THRESHOLD

        question = {
          id: :"reconciliation_needed_#{canonical_id}",
          text: "Findings for #{canonical_id} diverge significantly across documents — reconciliation needed.",
          dependencies: doc_indices.map { |i| namespaced_id(i, canonical_id) },
        }
        [question]
      end
    end
  end
end
