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

        result = Analysis::ConversationAnalyzer.new.build_result(
          compiled_turns, jsonl_path:, total:, topic_labels:, topic_shifts:
        )

        output(full_output(result, jsonl_path))
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      private def full_output(result, jsonl_path)
        {
          jsonl_path:,
          turn_count: result.turns.size,
          turns: result.turns.map { |t| Types.dump(t) },
          metadata: result.metadata,
          insights: result.insights,
          speaker_profiles: result.speaker_profiles.transform_values { |p| Types.dump(p) },
          tenor_timeline: result.tenor_timeline,
          field_evolution: result.field_evolution,
          correlations: result.correlations,
          key_moments: result.key_moments.map { |m| Types.dump(m) },
          example_passages: result.example_passages.map { |p| Types.dump(p) },
          topic_labels: result.topic_labels,
          topic_evolution: result.topic_evolution,
        }
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      private def compiled_turns
        payloads
          .select { |p| p[:class] == CompileTurnJob.to_s }
          .map { |p| Types.load_conversation_turn(p.fetch(:output)) }
          .sort_by(&:turn_id)
      end

      # Only present when the workflow ran a TopicModelJob (topics: was
      # requested) — payloads only ever held CompileTurnJob output before
      # TopicModelJob existed, so this is nil/[] (the build_result
      # defaults) for every workflow run without topic modeling.
      private def topic_labels
        topic_payload&.[](:topic_labels)&.transform_keys { |k| k.to_s.to_i }
      end

      private def topic_shifts
        topic_payload&.[](:topic_shifts) || []
      end

      private def topic_payload
        @topic_payload ||= Array(payloads).find { |p| p[:class] == TopicModelJob.to_s }&.fetch(:output)
      end
    end
  end
end
