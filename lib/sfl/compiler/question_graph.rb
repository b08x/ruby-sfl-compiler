# frozen_string_literal: true

module SFL
  module Compiler
    # Dependency DAG for multi-agent reasoning sprints.
    #
    # Every question supplies { id:, text:, dependencies: [] }. The graph
    # builds two adjacency lists — forward (children) and reverse (parents)
    # — from those edges and exposes them through named query methods.
    #
    # Construction fails immediately on two conditions: a dependency id that
    # names a question not present in the graph (unresolvable), or a cycle
    # detected during topological ordering.
    class QuestionGraph
      # @param questions [Array<Hash>] each { id:, text:, dependencies: [] }
      def initialize(questions)
        @nodes = questions.to_h { |q| [q.fetch(:id), q] }
        validate_dependencies!
        @children = build_children
        @parents  = build_parents
        @order    = kahn_sort
      end

      attr_reader :nodes
      alias questions nodes

      # Questions whose own id is never named as a dependency by anyone else.
      def roots = @nodes.keys.select { |id| @parents[id].empty? }

      # Questions that no other question depends on.
      def leaves = @nodes.keys.select { |id| @children[id].empty? }

      # Direct dependencies of +id+ (what it depends on).
      def parents(id) = @parents.fetch(id, [])

      # Questions that directly depend on +id+.
      def children(id) = @children.fetch(id, [])

      # All upstream questions reachable from +id+ by following parent edges.
      def ancestors(id) = bfs(@parents, id)

      # All downstream questions reachable from +id+ by following child edges.
      def descendants(id) = bfs(@children, id)

      # @return [Boolean]
      def reachable?(from:, to:) = descendants(from).include?(to)

      # Longest path (in hops) from any root to +id+.
      def depth(id)
        return 0 if @parents[id].empty?

        @parents[id].map { |p| depth(p) }.max + 1
      end

      # Questions in topological order (dependencies before dependents).
      def topological_order = @order

      private

      def validate_dependencies!
        @nodes.each_value do |q|
          q.fetch(:dependencies, []).each do |dep|
            next if @nodes.key?(dep)

            raise QuestionGraphError,
              "Unknown dependency #{dep.inspect} referenced by #{q.fetch(:id).inspect}"
          end
        end
      end

      # { id => [ids of questions that depend on id] }
      def build_children
        result = @nodes.transform_values { [] }
        @nodes.each_value do |q|
          q.fetch(:dependencies, []).each { |dep| result[dep] << q.fetch(:id) }
        end
        result
      end

      # { id => dependencies list } — mirrors the input's dependencies arrays
      def build_parents
        @nodes.transform_values { |q| q.fetch(:dependencies, []).dup }
      end

      def kahn_sort
        in_degree = @nodes.transform_values { |q| q.fetch(:dependencies, []).size }
        queue = @nodes.keys.select { |id| in_degree[id].zero? }
        order = []

        until queue.empty?
          id = queue.shift
          order << id
          @children[id].each do |child|
            in_degree[child] -= 1
            queue << child if in_degree[child].zero?
          end
        end

        return order if order.size == @nodes.size

        unresolved = @nodes.keys - order
        raise QuestionGraphError, "Cyclic dependencies among: #{unresolved.inspect}"
      end

      def bfs(adjacency, start)
        visited = []
        queue   = adjacency[start].dup

        until queue.empty?
          current = queue.shift
          next if visited.include?(current)

          visited << current
          queue.concat(adjacency[current])
        end

        visited
      end
    end
  end
end
