# frozen_string_literal: true

require "prime"

module SFL
  module Compiler
    # Encodes a question-dependency DAG as a single integer via prime
    # factorization (Gödel numbering).
    #
    # Every question (axiomatic or derived) consumes the next prime from
    # one shared sequence (2, 3, 5, 7, 11, ...), assigned in dependency
    # order (a question's dependencies are always assigned before it).
    # An axiomatic question (no dependencies) uses that prime directly as
    # its value. A derived question multiplies its own fresh "seed" prime
    # by the product of its dependencies' values — never the bare
    # product alone, so a derived question with exactly one dependency
    # can never collide with that dependency's own value (a derived
    # value is always composite; an axiomatic value is always a raw
    # prime).
    #
    # `#decode`/`#consistent?` check that every question's own value
    # divides the target integer (trivially true of the gödel_number
    # itself, since it's the product of every value) — this validates
    # the *encoding* (did construction actually multiply, not e.g. add,
    # somewhere), not blind recovery of dependency edges from an
    # arbitrary integer with no other context.
    class QuestionGraph
      # @param questions [Array<Hash>] each { id:, text:, dependencies: [] }
      def initialize(questions)
        @questions = questions.to_h { |q| [q.fetch(:id), q] }
        @values = assign_values
      end

      attr_reader :questions, :values

      # rubocop:disable Naming/AsciiIdentifiers -- intentional: this is a
      # Gödel numbering, and the card/track this implements names the
      # method with the umlaut throughout.
      # @return [Integer] product of every question's assigned value
      def gödel_number
        @values.values.reduce(1, :*)
      end

      # @param number [Integer]
      # @return [Hash{Integer => Integer}] prime => exponent
      def factor(number = gödel_number)
        Prime.prime_division(number).to_h
      end

      # @param number [Integer]
      # @return [Array<Symbol>] question ids whose own value divides number
      def decode(number = gödel_number)
        factored = factor(number)
        @values.select { |_id, value| divides?(value, factored) }.keys
      end
      # rubocop:enable Naming/AsciiIdentifiers

      # @return [Boolean]
      def consistent?
        decode.sort == @questions.keys.sort
      end

      private def divides?(value, factored)
        factor(value).all? { |prime, exponent| factored.fetch(prime, 0) >= exponent }
      end

      private def assign_values
        primes = Prime.each
        values = {}

        topological_order.each do |id|
          dependencies = @questions.fetch(id).fetch(:dependencies, [])
          seed = primes.next
          values[id] = dependencies.empty? ? seed : seed * dependencies.map { |dep| values.fetch(dep) }.reduce(:*)
        end

        values
      end

      # Kahn's algorithm: a question is only ready once every dependency
      # it names has already been ordered. Anything left unordered when
      # the queue drains is either a cycle or names a dependency id that
      # doesn't exist in this graph — both are unresolvable the same way.
      private def topological_order
        in_degree = @questions.transform_values { |q| q.fetch(:dependencies, []).size }
        dependents = dependents_by_id
        queue = @questions.keys.select { |id| in_degree[id].zero? }

        order = drain_queue(queue, in_degree, dependents)
        verify_fully_ordered!(order)
        order
      end

      private def drain_queue(queue, in_degree, dependents)
        order = []
        until queue.empty?
          id = queue.shift
          order << id
          dependents[id].each do |dependent|
            in_degree[dependent] -= 1
            queue << dependent if in_degree[dependent].zero?
          end
        end
        order
      end

      private def dependents_by_id
        dependents = Hash.new { |h, k| h[k] = [] }
        @questions.each_value do |question|
          question.fetch(:dependencies, []).each { |dep| dependents[dep] << question.fetch(:id) }
        end
        dependents
      end

      private def verify_fully_ordered!(order)
        return if order.size == @questions.size

        unresolved = @questions.keys - order
        raise QuestionGraphError, "Cyclic or unresolved dependencies among: #{unresolved.inspect}"
      end
    end
  end
end
