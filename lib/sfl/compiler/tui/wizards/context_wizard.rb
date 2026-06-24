# frozen_string_literal: true

require "gum"
require_relative "../../classification_registry"

module SFL
  module Compiler
    module TUI
      module Wizards
        # Gum-prompt front end for `sfl-analyze context`.
        class ContextWizard
          MOODS = ["(any)", *ClassificationRegistry.canonical_values(:mood)].freeze

          def run
            query = Prompts.blank_to_nil(Gum.input(header: "Query"))
            return unless query

            mood = Gum.choose(MOODS, header: "Mood filter")
            limit = Prompts.optional_int(Gum.input(value: "10", header: "Max clauses to retrieve")) || 10
            min_modality = Prompts.optional_float(
              Gum.input(placeholder: "(blank = no filter)", header: "Minimum modality (0.0-1.0)")
            )
            min_tenor = Prompts.optional_float(
              Gum.input(placeholder: "(blank = no filter)", header: "Minimum tenor (0.0-1.0)")
            )

            filters = {}
            filters[:mood] = mood if mood && mood != "(any)"
            filters[:min_modality] = min_modality if min_modality
            filters[:min_tenor] = min_tenor if min_tenor

            CLI.run_context(query, { output_dir: nil, limit:, filters: })
          end
        end
      end
    end
  end
end
