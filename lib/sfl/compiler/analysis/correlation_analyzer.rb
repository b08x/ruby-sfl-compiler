# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Analyzes correlations between field (process types) and tenor
      class CorrelationAnalyzer
        attr_reader :turns

        def initialize(turns)
          @turns = turns
        end

        # Correlate process types with tenor/modality
        # @return [Hash{String => Hash}] {process_type => {count:, avg_tenor:, avg_modality:}}
        def correlate_process_tenor
          all_clauses = turns.flat_map(&:clauses)

          all_clauses.group_by { |c| c.ideational.process_type }.transform_values do |clauses|
            tenors = clauses.map { |c| c.interpersonal.tenor }
            modalities = clauses.map { |c| c.interpersonal.modality_weight }

            {
              count: clauses.count,
              avg_tenor: mean(tenors),
              avg_modality: mean(modalities)
            }
          end
        end

        private

        def mean(values)
          return 0.0 if values.empty?
          (values.sum / values.count.to_f).round(3)
        end
      end
    end
  end
end
