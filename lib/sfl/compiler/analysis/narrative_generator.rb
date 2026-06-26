# frozen_string_literal: true

require "dspy"
require "dry-struct"

module SFL
  module Compiler
    module Analysis
      # Generates an LLM-written interpretive narrative from analysis data.
      # The Digest is the single input contract: built either from an
      # in-memory AnalysisResult (--narrative flag) or from a written
      # report JSON (narrate subcommand), producing identical text.
      class NarrativeGenerator
        SECTION_KEYS = %i[
          overview
          cast_and_roles
          interpersonal_dynamics
          conversational_arc
          data_quality
          takeaways
        ].freeze

        # @param narrator [#call, nil] (digest_text) → Hash of SECTION_KEYS;
        #   defaults to the DSPy-backed SFLNarrator. Injectable for tests.
        def initialize(narrator: nil)
          @narrator = narrator || -> (text) { SFLNarrator.new(text).call }
        end

        # @param digest [Digest]
        # @return [Types::NarrativeReport]
        # @raise [NarrativeError] on narrator failure or missing sections
        def generate(digest)
          sections = @narrator.call(digest.to_text)
          Types::NarrativeReport.new(
            source: digest.source,
            generated_at: Time.now,
            **sections.to_h.slice(*SECTION_KEYS)
          )
        rescue Dry::Struct::Error => e
          raise NarrativeError, "Narrative output missing or invalid sections: #{e.message}"
        rescue NarrativeError
          raise
        rescue => e
          raise NarrativeError, "Narrative generation failed: #{e.message}"
        end

        # Source-agnostic, string-keyed snapshot of an analysis, plus its
        # serialization to the exact text block the LLM receives.
        class Digest
          REQUIRED_TURN_KEYS = %w[
            turn_id
            speaker
            preview
            avg_tenor
            avg_modality
            dominant_mood
            clause_count
            defaulted_count
          ].freeze
          UNRELIABLE_THRESHOLD = 0.5
          PREVIEW_LENGTH = Formatters::JSONFormatter::PREVIEW_LENGTH

          attr_reader :metadata, :speaker_profiles, :correlations, :insights, :turns, :key_moments

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
                "defaulted_count" => t.clauses.count { |c| c.interpersonal.annotation_source != "llm" },
                "semantic_coherence_score" => t.semantic_coherence_score,
              }
            end
            key_moments = result.key_moments.map do |km|
              {
                "type" => km.type,
                "turn_id" => km.turn_id,
                "magnitude" => km.magnitude,
                "description" => km.description,
              }
            end
            new(
              # JSONFormatter merges annotation_coverage into metadata; this
              # path must too, or from_json/from_result texts diverge.
              metadata: deep_stringify(result.metadata.merge(annotation_coverage: coverage(result))),
              speaker_profiles: deep_stringify(profiles_hash(result.speaker_profiles)),
              correlations: deep_stringify(result.correlations),
              insights: result.insights,
              turns:,
              key_moments: deep_stringify(key_moments)
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
              turns: turns.map { |row| row.slice(*REQUIRED_TURN_KEYS, "tenor_shift", "semantic_coherence_score") },
              key_moments: parsed["key_moments"] || []
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
              defaulted_pct: clauses.empty? ? 0.0 : (defaulted * 100.0 / clauses.size).round(1),
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

          def initialize(metadata:, speaker_profiles:, correlations:, insights:, turns:, key_moments: [])
            @metadata = metadata
            @speaker_profiles = speaker_profiles
            @correlations = correlations
            @insights = insights
            @turns = turns
            @key_moments = key_moments
          end

          def source
            metadata["conversation_id"] || metadata["source_path"] || "unknown"
          end

          # The exact LLM input. Stable section order and formatting:
          # from_result and from_json must produce identical text.
          def to_text
            text = low_confidence_notice
            text += <<~TEXT
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

            if key_moments && !key_moments.empty?
              km_text = key_moments.map do |km|
                "[#{km['type']}] turn #{km['turn_id']} (magnitude: #{km['magnitude']}) — #{km['description']}"
              end.join("\n")
              text += "\n== KEY MOMENTS ==\n#{km_text}\n"
            end

            text
          end

          # Mirrors the markdown formatter's "Low Confidence" banner — a
          # small-sample analysis needs the same caveat carried into the
          # narrative's own text, not just buried as a metadata field.
          private def low_confidence_notice
            return "" unless metadata["low_confidence"]

            count = metadata["clause_count"]
            threshold = metadata["low_confidence_threshold"]
            "== LOW CONFIDENCE WARNING ==\n" \
              "This analysis is based on only #{count} clauses (minimum #{threshold} recommended). " \
              "Explicitly caveat the narrative as a small-sample, provisional analysis.\n\n"
          end

          private def turn_line(t)
            defaulted_pct =
              t["clause_count"].to_i.positive? ? t["defaulted_count"].to_f / t["clause_count"] : 0.0
            line = "turn #{t['turn_id']} [#{t['speaker']}] mood=#{t['dominant_mood']} " \
              "tenor=#{t['avg_tenor']} modality=#{t['avg_modality']} " \
              "shift=#{t['tenor_shift'].inspect} " \
              "clauses=#{t['clause_count']} defaulted=#{t['defaulted_count']}"
            line += " coherence=#{t['semantic_coherence_score']}" if t["semantic_coherence_score"]
            line += " UNRELIABLE (#{(defaulted_pct * 100).round}% fallback)" if defaulted_pct > UNRELIABLE_THRESHOLD
            "#{line}\n  preview: #{t['preview']}"
          end
        end
      end

      # DSPy signature: one call produces all six narrative sections.
      class NarrativeSignature < DSPy::Signature
        description "Compile the analysis digest into a structured SFL report. " \
          "Constraints: " \
          "1. State only data-backed SFL metrics (tenor, modality, coherence) and structural roles. " \
          "2. Exclude 'UNRELIABLE' turns from all dynamics calculations. " \
          "3. Prefix every conversational pivot with its Turn ID and shift magnitude. " \
          "4. Generate output strictly matching the required schema without conversational padding."

        input do
          const :analysis_digest, String,
            description: "Raw analysis data block containing metadata, speaker profiles, process/stance correlations, insights, turns, and key moments."
        end

        output do
          const :overview, String,
            description: "State the topic, participants, and setting. Limit 2 paragraphs."
          const :cast_and_roles, String,
            description: "Map speakers to transitivity grammar structures (Process types, Participant roles, Circumstances). Limit 1 paragraph per speaker."
          const :interpersonal_dynamics, String,
            description: "Report tenor and modality measurements. State numerical differences between speakers."
          const :conversational_arc, String,
            description: "Map the chronological sequence. Map every key moment to its Turn ID and shift magnitude."
          const :data_quality, String,
            description: "Report the fallback percentage and list UNRELIABLE turns. If LOW CONFIDENCE is true, prepend: 'WARNING: Clause count is below recommended threshold. Findings are provisional.'"
          const :takeaways, String,
            description: "Extract 3 to 5 numbered conclusions. Strictly enforce format: '1. [Conclusion] derived from [Metric].'"
        end
      end

      # Default DSPy-backed narrator.
      class SFLNarrator
        def initialize(digest_text)
          @digest_text = digest_text
        end

        # @return [Hash] symbol-keyed sections
        def call
          result = DSPy::ChainOfThought.new(NarrativeSignature).call(analysis_digest: @digest_text)
          NarrativeGenerator::SECTION_KEYS.to_h { |key| [key, result.public_send(key)] }
        end
      end
    end
  end
end
