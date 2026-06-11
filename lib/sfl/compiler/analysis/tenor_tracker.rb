# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Tracks tenor (formality) evolution across conversation turns
      class TenorTracker
        attr_reader :turns, :threshold

        def initialize(turns, threshold: 0.15)
          @turns = turns
          @threshold = threshold
        end

        # Calculate tenor shifts between consecutive turns (mutates turns in-place)
        def calculate_shifts
          turns.each_with_index do |turn, idx|
            if idx > 0
              shift = turn.avg_tenor - turns[idx - 1].avg_tenor
              # Mutate by replacing in the turns array with updated struct
              turns[idx] = turn.class.new(**turn.to_h.merge(tenor_shift: shift))
            end
          end
        end

        # Find significant tenor shifts (above threshold)
        # @return [Array<Hash>] Shift metadata
        def detect_significant_shifts
          calculate_shifts if turns.any? { |t| t.tenor_shift.nil? && t.turn_id > 1 }

          turns.select { |t| t.tenor_shift && t.tenor_shift.abs > threshold }.map do |turn|
            {
              turn_id: turn.turn_id,
              speaker: turn.speaker,
              from_tenor: turns[turn.turn_id - 2]&.avg_tenor,
              to_tenor: turn.avg_tenor,
              delta: turn.tenor_shift,
              direction: turn.tenor_shift > 0 ? "more formal" : "less formal"
            }
          end
        end
      end
    end
  end
end
