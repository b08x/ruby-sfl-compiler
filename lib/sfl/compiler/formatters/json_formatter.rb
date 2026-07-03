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
            turns: format_turns,
            tenor_timeline: result.tenor_timeline,
            field_evolution: result.field_evolution,
            correlations: result.correlations,
            insights: result.insights,
            topic_labels: result.topic_labels,
            topic_evolution: result.topic_evolution,
            key_moments: format_key_moments,
          }.merge(profiles_key => format_speaker_profiles)
        end

        # This formatter serves both `conversation` and `documentation`
        # analyses — DocumentationAnalyzer maps sections onto
        # ConversationTurn-shaped data (speaker: heading) so the shared
        # SpeakerProfiler/TenorTracker/CorrelationAnalyzer machinery works
        # unchanged (see CLAUDE.md). Internally result.metadata always
        # keeps the canonical conversation_id/turn_count/speakers keys —
        # Markdown/CSV already read those directly — but writing them
        # verbatim into a *documentation* report's JSON is wrong: a
        # section heading is not a "speaker". The JSON output below is
        # renamed to match the domain, driven by the same unit_label/
        # actor_label/actors_list_label/id_label metadata
        # DocumentationAnalyzer already sets for the Markdown/CSV labels;
        # conversation analyses set none of these, so their JSON is
        # unchanged (id_key/count_key/profiles_key/actors_key all resolve
        # to the original names).
        private def format_metadata
          meta = result.metadata.merge(annotation_coverage:)
          # In-place key substitution (not delete+reinsert) preserves the
          # original key order — Digest#to_text's METADATA section is a
          # literal `metadata.map { "#{k}: #{v}" }.join`, so reordering
          # keys would break the from_result/from_json text-equivalence
          # contract even when no rename actually applies.
          key_map = { conversation_id: id_key, turn_count: count_key, speakers: actors_key }
          meta.each_with_object({}) { |(k, v), renamed| renamed[key_map.fetch(k, k)] = v }
        end

        # Shared with NarrativeGenerator::Digest.from_json, which must
        # translate these same renamed JSON keys back to the canonical
        # conversation_id/turn_count/speakers/speaker_profiles vocabulary
        # (the equivalence contract with .from_result, which always reads
        # result.metadata directly — see PREVIEW_LENGTH's own comment
        # above for the same from_result/from_json parity concern).
        # Accepts metadata with either symbol or string keys since
        # from_json calls this with a JSON.parse'd (string-keyed) hash.
        def self.id_key_for(metadata)
          (metadata[:id_label] || metadata["id_label"] || "conversation_id").to_sym
        end

        def self.count_key_for(metadata)
          :"#{(metadata[:unit_label] || metadata['unit_label'] || 'turn').downcase}_count"
        end

        def self.profiles_key_for(metadata)
          :"#{(metadata[:actor_label] || metadata['actor_label'] || 'speaker').downcase}_profiles"
        end

        def self.actors_key_for(metadata)
          (metadata[:actors_list_label] || metadata["actors_list_label"] || "speakers").downcase.to_sym
        end

        private def id_key
          self.class.id_key_for(result.metadata)
        end

        private def count_key
          self.class.count_key_for(result.metadata)
        end

        private def profiles_key
          self.class.profiles_key_for(result.metadata)
        end

        private def actors_key
          self.class.actors_key_for(result.metadata)
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
