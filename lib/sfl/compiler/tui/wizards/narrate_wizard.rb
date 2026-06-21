# frozen_string_literal: true

require "gum"

module SFL
  module Compiler
    module TUI
      module Wizards
        # Gum-prompt front end for `sfl-analyze narrate`.
        class NarrateWizard
          def run
            input = Gum.file(file: true, directory: false)
            return unless input

            output_dir = Prompts.blank_to_nil(
              Gum.input(placeholder: "(blank = same directory as the JSON)", header: "Output directory")
            )

            CLI.run_narrate(input, { output_dir: })
          end
        end
      end
    end
  end
end
