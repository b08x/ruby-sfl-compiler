# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Generates an LLM-written interpretive narrative from analysis data.
      # The Digest is the single input contract: built either from an
      # in-memory AnalysisResult (--narrative flag) or from a written
      # report JSON (narrate subcommand), producing identical text.
      class NarrativeGenerator
        # Source-agnostic, string-keyed snapshot of an analysis, plus its
        # serialization to the exact text block the LLM receives.
        class Digest
          REQUIRED_TURN_KEYS = %w[
            turn_id speaker preview avg_tenor avg_modality dominant_mood
            clause_count defaulted_count
          ].freeze
          UNRELIABLE_THRESHOLD = 0.5
          PREVIEW_LENGTH = Formatters::JSONFormatter::PREVIEW_LENGTH

          attr_reader :metadata, :speaker_profiles, :correlations, :insights, :turns

          # @param result [Types::AnalysisResult]
          # @return [Digest]
          def self.from_result(result)
            turns = result.turns.map do |t|
              {
                "turn_id" => t.turn_id,
                "speaker" => t.speaker,
                "preview" => t.message_text[0, PREVIEW_LENGTH],
                "avg_tenor" => t.avg_tenor,
                "avg_modality" => t.avg_modality,
                "dominant_mood" => t.dominant_mood,
                "tenor_shift" => t.tenor_shift,
                "clause_count" => t.clauses.size,
                "defaulted_count" => t.clauses.count { |c| c.interpersonal.annotation_source != "llm" }
              }
            end
            new(
              # JSONFormatter merges annotation_coverage into metadata; this
              # path must too, or from_json/from_result texts diverge.
              metadata: deep_stringify(result.metadata.merge(annotation_coverage: coverage(result))),
              speaker_profiles: deep_stringify(profiles_hash(result.speaker_profiles)),
              correlations: deep_stringify(result.correlations),
              insights: result.insights,
              turns: turns
            )
          end

          # @param parsed [Hash] JSON.parse of a report written by JSONFormatter
          # @return [Digest]
          # @raise [NarrativeError] if the JSON predates the turns array or rows are malformed
          def self.from_json(parsed)
            turns = parsed["turns"]
            if turns.nil?
              raise NarrativeError,
                "Report JSON has no `turns` array — it predates narrative " \
                "support. Re-run the analysis to regenerate it."
            end
            turns.each do |row|
              REQUIRED_TURN_KEYS.each do |key|
                raise NarrativeError, "Turn row missing required key: #{key}" unless row.key?(key)
              end
            end
            new(
              metadata: parsed.fetch("metadata", {}),
              speaker_profiles: parsed.fetch("speaker_profiles", {}),
              correlations: parsed.fetch("correlations", {}),
              insights: parsed.fetch("insights", []),
              turns: turns.map { |row| row.slice(*REQUIRED_TURN_KEYS, "tenor_shift") }
            )
          end

          # Identical formula to JSONFormatter#annotation_coverage (the
          # equivalence contract requires matching values, incl. rounding).
          def self.coverage(result)
            clauses = result.turns.flat_map(&:clauses)
            sources = clauses.map { |c| c.interpersonal.annotation_source }.tally
            defaulted = clauses.size - sources.fetch("llm", 0)
            {
              total_clauses: clauses.size,
              llm: sources.fetch("llm", 0),
              fallback: sources.fetch("fallback", 0),
              stub: sources.fetch("stub", 0),
              defaulted_pct: clauses.empty? ? 0.0 : (defaulted * 100.0 / clauses.size).round(1)
            }
          end

          def self.profiles_hash(profiles)
            profiles.transform_values do |p|
              p.respond_to?(:to_h) ? p.to_h.except(:speaker_name) : p
            end
          end

          def self.deep_stringify(obj)
            case obj
            when Hash  then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = deep_stringify(v) }
            when Array then obj.map { |v| deep_stringify(v) }
            else obj
            end
          end

          def initialize(metadata:, speaker_profiles:, correlations:, insights:, turns:)
            @metadata = metadata
            @speaker_profiles = speaker_profiles
            @correlations = correlations
            @insights = insights
            @turns = turns
          end

          def source
            metadata["conversation_id"] || metadata["source_path"] || "unknown"
          end

          # The exact LLM input. Stable section order and formatting:
          # from_result and from_json must produce identical text.
          def to_text
            <<~TEXT
              == METADATA ==
              #{metadata.map { |k, v| "#{k}: #{v}" }.join("\n")}

              == SPEAKER PROFILES ==
              #{speaker_profiles.map { |name, p| "#{name}: #{p}" }.join("\n")}

              == PROCESS/STANCE CORRELATIONS ==
              #{correlations.map { |k, v| "#{k}: #{v}" }.join("\n")}

              == MACHINE INSIGHTS ==
              #{insights.join("\n")}

              == TURNS (in order) ==
              #{turns.map { |t| turn_line(t) }.join("\n")}
            TEXT
          end

          private

          def turn_line(t)
            defaulted_pct =
              t["clause_count"].to_i.positive? ? t["defaulted_count"].to_f / t["clause_count"] : 0.0
            line = "turn #{t['turn_id']} [#{t['speaker']}] mood=#{t['dominant_mood']} " \
                   "tenor=#{t['avg_tenor']} modality=#{t['avg_modality']} " \
                   "shift=#{t['tenor_shift'].inspect} " \
                   "clauses=#{t['clause_count']} defaulted=#{t['defaulted_count']}"
            line += " UNRELIABLE (#{(defaulted_pct * 100).round}% fallback)" if defaulted_pct > UNRELIABLE_THRESHOLD
            "#{line}\n  preview: #{t['preview']}"
          end
        end
      end
    end
  end
end
