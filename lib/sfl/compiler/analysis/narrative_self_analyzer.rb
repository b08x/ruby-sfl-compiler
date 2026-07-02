# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Runs narrative_report.md text back through the SFL pipeline and
      # compares its interpersonal profile against the source AnalysisResult.
      #
      # A high `strange_loop_divergence` (> 0.3) means the narrative invented
      # interpersonal structure not present in the source — the generator
      # overstated tension, formality, or mood without grounding.
      class NarrativeSelfAnalyzer
        DIVERGENCE_FLAG_THRESHOLD = 0.3

        # @!attribute [r] tenor_delta
        #   Absolute difference in avg tenor between narrative and source.
        # @!attribute [r] mood_delta
        #   L1/2 distance between mood distributions (0–1).
        # @!attribute [r] modality_delta
        #   Absolute difference in avg modality_weight.
        # @!attribute [r] strange_loop_divergence
        #   Mean of the three deltas, clamped to 0–1.
        # @!attribute [r] flagged
        #   true when divergence > DIVERGENCE_FLAG_THRESHOLD.
        # @!attribute [r] narrative_profile
        #   { avg_tenor:, avg_modality:, mood_distribution: } for the narrative.
        # @!attribute [r] source_profile
        #   Same structure for the source AnalysisResult.
        # @!attribute [r] error
        #   Non-nil when analysis could not proceed (empty text, no clauses).
        Result = Struct.new(
          :tenor_delta, :mood_delta, :modality_delta,
          :strange_loop_divergence, :flagged,
          :narrative_profile, :source_profile,
          :error,
          keyword_init: true
        )

        # @param pipeline [Pipeline] configured pipeline instance
        def initialize(pipeline:)
          @pipeline = pipeline
        end

        # Convenience class method for one-shot analysis from a file path.
        #
        # @param narrative_path [String] path to narrative_report.md
        # @param pipeline [Pipeline]
        # @param source_result [Types::AnalysisResult]
        # @return [Result]
        def self.analyze(narrative_path, pipeline:, source_result:)
          new(pipeline:).analyze(File.read(narrative_path), source_result:)
        end

        # @param narrative_text [String] full narrative prose
        # @param source_result [Types::AnalysisResult]
        # @return [Result]
        def analyze(narrative_text, source_result:)
          source_profile = build_source_profile(source_result)

          if narrative_text.strip.empty?
            return Result.new(
              tenor_delta: 1.0, mood_delta: 1.0, modality_delta: 1.0,
              strange_loop_divergence: 1.0, flagged: true,
              narrative_profile: empty_profile, source_profile:,
              error: "empty narrative"
            )
          end

          clauses = @pipeline.compile(narrative_text,
            document_id: "narrative-self-check",
            store: false,
            embed: false)

          if clauses.empty?
            return Result.new(
              tenor_delta: 1.0, mood_delta: 1.0, modality_delta: 1.0,
              strange_loop_divergence: 1.0, flagged: true,
              narrative_profile: empty_profile, source_profile:,
              error: "pipeline produced no clauses"
            )
          end

          narrative_profile = build_profile(clauses)

          tenor_delta    = (narrative_profile[:avg_tenor]    - source_profile[:avg_tenor]).abs
          modality_delta = (narrative_profile[:avg_modality] - source_profile[:avg_modality]).abs
          mood_delta     = mood_distribution_delta(narrative_profile[:mood_distribution],
            source_profile[:mood_distribution])

          divergence = ((tenor_delta + modality_delta + mood_delta) / 3.0).clamp(0.0, 1.0)

          Result.new(
            tenor_delta:,
            mood_delta:,
            modality_delta:,
            strange_loop_divergence: divergence,
            flagged: divergence > DIVERGENCE_FLAG_THRESHOLD,
            narrative_profile:,
            source_profile:,
            error: nil
          )
        end

        private

        def build_profile(clauses)
          inter        = clauses.map(&:interpersonal)
          avg_tenor    = mean(inter.map(&:tenor))
          avg_modality = mean(inter.map(&:modality_weight))
          mood_dist    = inter.map(&:mood).tally.transform_values { |v| v.to_f / inter.size }
          { avg_tenor:, avg_modality:, mood_distribution: mood_dist }
        end

        def build_source_profile(result)
          clauses = result.turns.flat_map(&:clauses)
          return empty_profile if clauses.empty?

          build_profile(clauses)
        end

        # L1 distance between two probability distributions, normalised to [0, 1].
        # Max L1 between any two distributions over the same support is 2.0.
        def mood_distribution_delta(dist_a, dist_b)
          all_moods = dist_a.keys | dist_b.keys
          return 0.0 if all_moods.empty?

          l1 = all_moods.sum { |m| (dist_a.fetch(m, 0.0) - dist_b.fetch(m, 0.0)).abs }
          l1 / 2.0
        end

        def mean(values)
          return 0.0 if values.empty?

          values.sum / values.size.to_f
        end

        def empty_profile
          { avg_tenor: 0.0, avg_modality: 0.0, mood_distribution: {} }
        end
      end
    end
  end
end
