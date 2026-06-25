# frozen_string_literal: true

require "json"

module SFL
  module Compiler
    module Formatters
      # Exports conversation analysis to JSON format
      class JSONFormatter < BaseFormatter
        # Must match Analysis::NarrativeGenerator::Digest::PREVIEW_LENGTH — the
        # narrate digest built from this JSON must equal one built in-memory.
        PREVIEW_LENGTH = 200

        def render
          JSON.pretty_generate(build_hash)
        end

        private def build_hash
          {
            metadata: format_metadata,
            speaker_profiles: format_speaker_profiles,
            turns: format_turns,
            tenor_timeline: result.tenor_timeline,
            field_evolution: result.field_evolution,
            correlations: result.correlations,
            insights: result.insights,
            topic_labels: result.topic_labels,
            topic_evolution: result.topic_evolution,
            key_moments: format_key_moments,
          }
        end

        private def format_metadata
          # analyzed_at is already a string (ISO8601) from the script
          result.metadata.merge(annotation_coverage:)
        end

        # Per-source clause counts so consumers can tell real LLM annotations
        # from fallback/stub defaults (which all sit at 0.5 and bias averages).
        private def annotation_coverage
          clauses = result.turns.flat_map(&:clauses)
          sources = clauses.map { |c| c.interpersonal.annotation_source }.tally
          defaulted = clauses.size - sources.fetch("llm", 0)

          {
            total_clauses: clauses.size,
            llm: sources.fetch("llm", 0),
            fallback: sources.fetch("fallback", 0),
            stub: sources.fetch("stub", 0),
            defaulted_pct: clauses.empty? ? 0.0 : (defaulted * 100.0 / clauses.size).round(1),
          }
        end

        # Per-turn rows with preview text and provenance counts. This makes the
        # JSON report self-contained: `sfl-analyze narrate` grounds its narrative
        # entirely from this file.
        private def format_turns
          result.turns.map do |turn|
            {
              turn_id: turn.turn_id,
              speaker: turn.speaker,
              timestamp: turn.timestamp.iso8601,
              preview: turn.message_text[0, PREVIEW_LENGTH],
              avg_tenor: turn.avg_tenor,
              avg_modality: turn.avg_modality,
              dominant_mood: turn.dominant_mood,
              tenor_shift: turn.tenor_shift,
              clause_count: turn.clauses.size,
              defaulted_count: turn.clauses.count { |c| c.interpersonal.annotation_source != "llm" },
              dominant_topic: turn.dominant_topic,
              topic_distribution: turn.topic_distribution,
              semantic_coherence_score: turn.semantic_coherence_score,
              clauses: format_clauses(turn.clauses),
            }
          end
        end

        # Per-clause reasoning_trace, the only clause-level field this
        # report exposes today. `nil` for fallback/stub clauses (no trace
        # was ever computed) as well as for llm clauses where the trace
        # itself failed Dry::Struct validation (PassTwoEngine leaves
        # reasoning_trace nil in that case without defaulting the rest of
        # the clause — see `safe_reasoning_trace_from`).
        private def format_clauses(clauses)
          clauses.map do |clause|
            {
              id: clause.id,
              annotation_source: clause.interpersonal.annotation_source,
              reasoning_trace: serialize_reasoning_trace(clause.interpersonal.reasoning_trace),
            }
          end
        end

        private def serialize_reasoning_trace(trace)
          return nil unless trace

          Types.deep_stringify_time(trace.to_h)
        end

        private def format_speaker_profiles
          result.speaker_profiles.transform_values do |profile|
            {
              turn_count: profile.turn_count,
              avg_tenor: profile.avg_tenor,
              tenor_range: profile.tenor_range,
              tenor_variance: profile.tenor_variance,
              avg_modality: profile.avg_modality,
              mood_distribution: profile.mood_distribution,
              dominant_processes: profile.dominant_processes,
            }
          end
        end

        private def format_key_moments
          result.key_moments.map do |km|
            {
              type: km.type,
              turn_id: km.turn_id,
              magnitude: km.magnitude,
              description: km.description,
            }
          end
        end
      end
    end
  end
end
