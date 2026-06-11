# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Builds aggregated profiles for speakers in a conversation
      class SpeakerProfiler
        attr_reader :turns

        def initialize(turns)
          @turns = turns
        end

        # Build profile for speaker from their turns
        # @return [Types::SpeakerProfile]
        def build_profile
          raise ArgumentError, "No turns provided" if turns.empty?

          speaker_name = turns.first.speaker
          tenors = turns.map(&:avg_tenor)
          modalities = turns.map(&:avg_modality)

          Types::SpeakerProfile.new(
            speaker_name: speaker_name,
            turn_count: turns.count,
            avg_tenor: mean(tenors),
            tenor_range: [tenors.min, tenors.max],
            tenor_variance: variance(tenors),
            avg_modality: mean(modalities),
            mood_distribution: calculate_mood_distribution,
            dominant_processes: aggregate_process_types
          )
        end

        # Build profiles for all speakers in conversation
        # @param all_turns [Array<ConversationTurn>]
        # @return [Hash{String => SpeakerProfile}]
        def self.build_profiles(all_turns)
          all_turns.group_by(&:speaker).transform_values do |speaker_turns|
            new(speaker_turns).build_profile
          end
        end

        private

        def calculate_mood_distribution
          mood_counts = turns.each_with_object(Hash.new(0)) do |turn, counts|
            counts[turn.dominant_mood] += 1
          end

          total = turns.count.to_f
          mood_counts.transform_values { |count| (count / total).round(3) }
        end

        def aggregate_process_types
          turns.each_with_object(Hash.new(0)) do |turn, totals|
            turn.process_types.each do |process_type, count|
              totals[process_type] += count
            end
          end
        end

        def mean(values)
          return 0.0 if values.empty?
          (values.sum / values.count.to_f).round(3)
        end

        def variance(values)
          return 0.0 if values.count < 2

          avg = mean(values)
          sum_squares = values.sum { |v| (v - avg)**2 }
          (sum_squares / values.count.to_f).round(4)
        end
      end
    end
  end
end
