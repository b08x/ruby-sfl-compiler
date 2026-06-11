# frozen_string_literal: true

require "json"

module SFL
  module Compiler
    module Formatters
      # Exports conversation analysis to JSON format
      class JSONFormatter < BaseFormatter
        def render
          JSON.pretty_generate(build_hash)
        end

        private

        def build_hash
          {
            metadata: format_metadata,
            speaker_profiles: format_speaker_profiles,
            tenor_timeline: result.tenor_timeline,
            field_evolution: result.field_evolution,
            correlations: result.correlations,
            insights: result.insights
          }
        end

        def format_metadata
          # analyzed_at is already a string (ISO8601) from the script
          result.metadata
        end

        def format_speaker_profiles
          result.speaker_profiles.transform_values do |profile|
            {
              turn_count: profile.turn_count,
              avg_tenor: profile.avg_tenor,
              tenor_range: profile.tenor_range,
              tenor_variance: profile.tenor_variance,
              avg_modality: profile.avg_modality,
              mood_distribution: profile.mood_distribution,
              dominant_processes: profile.dominant_processes
            }
          end
        end
      end
    end
  end
end
