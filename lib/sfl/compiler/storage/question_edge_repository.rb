# frozen_string_literal: true

module SFL
  module Compiler
    # Persists and reconstructs QuestionGraph edges.
    #
    # Each directed edge (parent_id → child_id) is stored as one row.
    # `depth` is precomputed at write time from the in-memory graph so
    # depth queries are O(1) without a recursive CTE.
    #
    # Reachability beyond the immediate adjacency list uses a recursive
    # CTE when the caller needs it — see #reachable.
    class QuestionEdgeRepository
      TABLE = :question_edges

      def initialize(db)
        @db = db
      end

      # Persist all edges in graph. Idempotent: removes existing edges
      # for the node set before inserting.
      #
      # @param graph [QuestionGraph]
      def store(graph)
        node_ids = graph.nodes.keys.map(&:to_s)

        @db.transaction do
          @db[TABLE].where(parent_id: node_ids).delete
          @db[TABLE].where(child_id: node_ids).delete

          graph.nodes.each_key do |parent_id|
            graph.children(parent_id).each do |child_id|
              @db[TABLE].insert(
                parent_id:  parent_id.to_s,
                child_id:   child_id.to_s,
                depth:      graph.depth(child_id),
                created_at: Time.now
              )
            end
          end
        end
      end

      # Reconstruct a QuestionGraph from persisted edges.
      # Callers supply node metadata (id + text); dependency wiring
      # comes from the database.
      #
      # @param questions [Array<Hash>] each { id:, text: }
      # @return [QuestionGraph]
      def reconstruct(questions)
        ids  = questions.map { |q| q.fetch(:id).to_s }
        rows = @db[TABLE].where(child_id: ids).all

        deps = {}
        rows.each do |row|
          (deps[row[:child_id]] ||= []) << row[:parent_id]
        end

        enriched = questions.map do |q|
          q.merge(dependencies: deps[q.fetch(:id).to_s] || [])
        end

        QuestionGraph.new(enriched)
      end

      # Descendant node ids reachable from start_id via a recursive CTE.
      # Useful when the full graph is not loaded in memory.
      #
      # @param start_id [String]
      # @return [Array<String>]
      def reachable(start_id)
        rows = @db.fetch(<<~SQL, start_id.to_s).all
          WITH RECURSIVE descendants AS (
            SELECT child_id FROM question_edges WHERE parent_id = ?
            UNION
            SELECT qe.child_id
              FROM question_edges qe
              JOIN descendants d ON qe.parent_id = d.child_id
          )
          SELECT child_id FROM descendants
        SQL
        rows.map { |r| r[:child_id] }
      end
    end
  end
end
