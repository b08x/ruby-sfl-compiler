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
            raw_metadata = parsed.fetch("metadata", {})
            new(
              metadata: canonicalize_metadata(raw_metadata),
              speaker_profiles: parsed.fetch(Formatters::JSONFormatter.profiles_key_for(raw_metadata).to_s, {}),
              correlations: parsed.fetch("correlations", {}),
              insights: parsed.fetch("insights", []),
              turns: turns.map { |row| row.slice(*REQUIRED_TURN_KEYS, "tenor_shift", "semantic_coherence_score") },
              key_moments: parsed["key_moments"] || []
            )
          end

          # JSONFormatter renames conversation_id/turn_count/speakers to
          # domain-correct keys for documentation reports (document_id/
          # section_count/headings) — translate back to the canonical
          # vocabulary this Digest always works in, so from_json produces
          # metadata identical to from_result (which reads result.metadata
          # directly, where these keys are never renamed).
          def self.canonicalize_metadata(meta)
            # In-place key substitution (not delete+reinsert) preserves
            # key order, matching JSONFormatter#format_metadata's own
            # approach — required for the from_result/from_json text
            # equivalence contract (see #to_text).
            key_map = {
              Formatters::JSONFormatter.id_key_for(meta).to_s => "conversation_id",
              Formatters::JSONFormatter.count_key_for(meta).to_s => "turn_count",
              Formatters::JSONFormatter.actors_key_for(meta).to_s => "speakers",
            }
            meta.each_with_object({}) { |(k, v), renamed| renamed[key_map.fetch(k, k)] = v }
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

      # DSPy signature: Achilles role — proposes a draft narrative from the digest.
      # Outputs the draft plus a numbered list of grounded claims for Tortoise to challenge.
      class NarrativeProposeSignature < DSPy::Signature
        description "Draft an interpretive analytical narrative of a conversation analyzed " \
          "with Systemic Functional Linguistics. Ground every claim in the supplied " \
          "statistics or message previews. Produce a single continuous prose draft " \
          "covering: overview, speakers' roles, interpersonal dynamics, conversational arc, " \
          "data quality caveats, and key takeaways. Then enumerate all factual claims you " \
          "made, each citing a specific statistic or quote from the digest."

        input do
          const :analysis_digest, String,
            description: "Statistics, speaker profiles, correlations, and per-turn stance rows"
        end

        output do
          const :narrative_draft, String,
            description: "Complete first-draft narrative prose covering all six analytical sections"
          const :claims, String,
            description: "Numbered list of factual claims in the draft, each citing a specific " \
              "statistic or quote from the analysis digest (one claim per line)"
        end
      end

      # DSPy signature: Tortoise role — skeptical challenge of the proposed draft.
      # Produces challenges and a citation_coverage float (0.0–1.0).
      class NarrativeChallengeSignature < DSPy::Signature
        description "You are a skeptical reviewer of an SFL analytical narrative. " \
          "Read the draft and its claim list against the original analysis digest. " \
          "For each claim, determine whether it is genuinely grounded in a statistic, " \
          "quote, or pattern from the digest. Identify overstated, unsupported, or " \
          "interpretively inflated claims. Compute the fraction of claims that are " \
          "fully grounded (citation_coverage). A claim is grounded only if a reader " \
          "could verify it directly from the digest numbers or previews — inference " \
          "alone is not grounding."

        input do
          const :analysis_digest, String,
            description: "The original analysis data the narrative should be grounded in"
          const :narrative_draft, String,
            description: "The proposed draft narrative with its claim list"
        end

        output do
          const :challenges, String,
            description: "Specific challenges to ungrounded or overstated claims (one per line). " \
              "Empty string if all claims are grounded."
          const :citation_coverage, Float,
            description: "Fraction of claims fully grounded in the digest (0.0 = none, 1.0 = all)"
        end
      end

      # DSPy signature: Genie role — final synthesis incorporating Tortoise's challenges.
      # Produces the six polished narrative sections.
      class NarrativeVerifySignature < DSPy::Signature
        description "You are the final author of an SFL analytical narrative. " \
          "You have a draft narrative, a skeptical challenger's notes on ungrounded claims, " \
          "and the original analysis digest. Revise the draft to address all challenges: " \
          "remove or qualify unsupported claims, sharpen grounded ones, and ensure every " \
          "interpretive statement is traceable to the digest. Output the six standard " \
          "analytical sections as refined, publication-ready prose."

        input do
          const :analysis_digest, String,
            description: "The original analysis statistics and turn data"
          const :narrative_draft, String,
            description: "Achilles's proposed draft narrative"
          const :challenges, String,
            description: "Tortoise's challenges to ungrounded claims in the draft"
        end

        output do
          const :overview, String, description: "What this conversation is: topic, participants, setting"
          const :cast_and_roles, String, description: "Each speaker's role as the grammar reveals it"
          const :interpersonal_dynamics, String, description: "Tenor/modality patterns and shifts between speakers"
          const :conversational_arc, String, description: "Phases, pivots, and how the interaction resolves"
          const :data_quality, String, description: "Annotation coverage caveats; which turns are unmeasured"
          const :takeaways, String, description: "Three to five grounded conclusions"
        end
      end

      # DSPy signature: one call produces all six narrative sections.
      class NarrativeSignature < DSPy::Signature
        description "Write an interpretive analytical narrative of a " \
          "conversation analyzed with Systemic Functional Linguistics. " \
          "Ground every claim in the supplied statistics; quote message " \
          "previews where they illustrate a point. NEVER interpret " \
          "tenor/modality values from turns marked UNRELIABLE — " \
          "describe those turns as unmeasured. Use the KEY MOMENTS entries " \
          "as explicit evidence when describing pivots and anomalies in " \
          "the conversational arc. If the digest opens with a LOW " \
          "CONFIDENCE WARNING, state plainly in data_quality (and " \
          "takeaways) that the analysis rests on a small sample and " \
          "findings are provisional. Style exemplar: " \
          "'Robert is the only speaker who uses imperatives — in SFL " \
          "terms, the only one demanding rather than giving. That " \
          "asymmetry is the facilitator role, recovered from grammar " \
          "alone.' Write clear analytical prose, not bullet dumps."

        input do
          const :analysis_digest, String,
            description: "Statistics, speaker profiles, correlations, and " \
              "per-turn stance rows with message previews"
        end

        output do
          const :overview, String, description: "What this conversation is: topic, participants, setting"
          const :cast_and_roles, String, description: "Each speaker's role as the grammar reveals it"
          const :interpersonal_dynamics, String, description: "Tenor/modality patterns and shifts between speakers"
          const :conversational_arc, String, description: "Phases, pivots, and how the interaction resolves"
          const :data_quality, String, description: "Annotation coverage caveats; which turns are unmeasured"
          const :takeaways, String, description: "Three to five grounded conclusions"
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

      # Multi-model narrator: Achilles proposes, Tortoise challenges (with
      # citation_coverage), Genie synthesizes the final narrative. Retries
      # Achilles up to MAX_ATTEMPTS times when citation_coverage is below
      # CITATION_THRESHOLD; falls back to best-effort with a warning in
      # data_quality after all attempts are exhausted.
      #
      # @example
      #   narrator = MultiModelNarrator.new(
      #     generation_model: "openrouter/anthropic/claude-haiku-4",
      #     verification_model: "openrouter/anthropic/claude-sonnet-4-5"
      #   )
      #   NarrativeGenerator.new(narrator:).generate(digest)
      class MultiModelNarrator
        MAX_ATTEMPTS       = 2
        CITATION_THRESHOLD = 0.8

        # @param generation_model  [String] DSPy provider string for Achilles (propose)
        # @param verification_model [String] DSPy provider string for Genie (verify)
        # @param tortoise_model    [String, nil] defaults to generation_model
        # @raise [ArgumentError] if generation_model == verification_model
        def initialize(generation_model:, verification_model:, tortoise_model: nil)
          if generation_model == verification_model
            raise ArgumentError,
              "generation_model and verification_model must differ " \
                "(got '#{generation_model}' for both) — using the same model " \
                "for generation and verification defeats the RLHF-style " \
                "cross-checking purpose of multi-model narration"
          end

          @achilles_lm = generation_model
          @genie_lm    = verification_model
          @tortoise_lm = tortoise_model || generation_model
        end

        # @param digest_text [String] output of NarrativeGenerator::Digest#to_text
        # @return [Hash] symbol-keyed sections (same shape as SFLNarrator)
        def call(digest_text)
          last = nil

          MAX_ATTEMPTS.times do |attempt|
            draft     = run_achilles(digest_text)
            challenge = run_tortoise(digest_text, draft.narrative_draft)
            coverage  = challenge.citation_coverage.to_f
            last      = { draft:, challenge:, coverage: }

            return finalize(digest_text, draft.narrative_draft, challenge.challenges) if coverage >= CITATION_THRESHOLD

            warn "[WARN] NarrativeGenerator: citation_coverage #{coverage.round(2)} below " \
              "#{CITATION_THRESHOLD} (attempt #{attempt + 1}/#{MAX_ATTEMPTS}), regenerating…"
          end

          # Best-effort: Genie synthesizes anyway; warning surfaces in report
          sections = finalize(digest_text, last[:draft].narrative_draft, last[:challenge].challenges)
          coverage_note = "\n\n⚠️ Low citation coverage (#{last[:coverage].round(2)}) after " \
            "#{MAX_ATTEMPTS} attempts — narrative may contain ungrounded claims."
          sections.merge(data_quality: sections[:data_quality] + coverage_note)
        end

        private def run_achilles(digest_text)
          predictor(NarrativeProposeSignature, @achilles_lm)
            .call(analysis_digest: digest_text)
        end

        private def run_tortoise(digest_text, narrative_draft)
          predictor(NarrativeChallengeSignature, @tortoise_lm)
            .call(analysis_digest: digest_text, narrative_draft:)
        end

        private def finalize(digest_text, narrative_draft, challenges)
          result = predictor(NarrativeVerifySignature, @genie_lm)
            .call(analysis_digest: digest_text, narrative_draft:, challenges:)
          NarrativeGenerator::SECTION_KEYS.to_h { |key| [key, result.public_send(key)] }
        end

        private def predictor(signature_class, lm_provider)
          p = DSPy::ChainOfThought.new(signature_class)
          p.configure { |c| c.lm = build_lm(lm_provider) }
          p
        end

        private def build_lm(provider)
          DSPy::LM.new(provider, api_key: Bootstrap.api_key_for(provider, ENV))
        end
      end
    end
  end
end
