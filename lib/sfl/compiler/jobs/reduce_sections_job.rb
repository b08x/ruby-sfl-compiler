# frozen_string_literal: true

require "gush"

module SFL
  module Compiler
    # Fan-in job for documentation: reassembles every CompileSectionJob's
    # ConversationTurn output, then delegates to
    # DocumentationAnalyzer#build_result for chunk-artifact detection and
    # all cross-section aggregation.
    #
    # Mirrors ReduceTurnsJob's structure — same JSON round-trip, same
    # class-filter pattern, same full_output shape.
    class ReduceSectionsJob < Gush::Job
      def perform
        path          = params.fetch(:path)
        total         = params.fetch(:total)
        sprint_id     = params.fetch(:sprint_id, nil)
        sections_meta = params.fetch(:sections_meta, [])

        result = Analysis::DocumentationAnalyzer.new(pipeline: nil).build_result(
          compiled_turns,
          path:,
          total:,
          interrupted: compiled_turns.size < total,
          sections_meta:,
          topic_labels:,
          topic_shifts:,
          sprint_id:
        )

        output(full_output(result, path))
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
      private def full_output(result, path)
        {
          path:,
          section_count: result.turns.size,
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
        @compiled_turns ||= payloads
          .select { |p| p[:class] == CompileSectionJob.to_s }
          .map { |p| Types.load_conversation_turn(p.fetch(:output)) }
          .sort_by(&:turn_id)
      end

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
