# frozen_string_literal: true

# Zeitwerk autoloads this file the moment SFL::Compiler::ReduceTurnsJob is
# referenced, which happens independently of whether Bootstrap.call(
# require_jobs: true) has run in this process. Bootstrap's own `require
# "gush"` (in #configure_jobs) is too late for this class definition, since
# subclassing Gush::Job below needs the constant to already exist — so this
# file requires it directly, the same way CompileTurnJob does.
require "gush"

module SFL
  module Compiler
    # Fan-in job: reconstructs every CompileTurnJob's output back into
    # Types::ConversationTurn instances and runs the same cross-turn
    # aggregation tail ConversationAnalyzer#analyze always ran inline —
    # extracted to #build_result so both call paths share one
    # implementation.
    class ReduceTurnsJob < Gush::Job
      def perform
        jsonl_path = params.fetch(:jsonl_path)
        total = params.fetch(:total)

        turns = payloads
          .map { |p| Types.load_conversation_turn(p.fetch(:output)) }
          .sort_by(&:turn_id)

        result = Analysis::ConversationAnalyzer.new.build_result(turns, jsonl_path:, total:)

        output(
          jsonl_path:,
          turn_count: result.turns.size,
          metadata: result.metadata,
          insights: result.insights
        )
      end
    end
  end
end
