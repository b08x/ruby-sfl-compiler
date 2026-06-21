# frozen_string_literal: true

require "gum"

module SFL
  module Compiler
    module TUI
      module Wizards
        # Gum-prompt front end for `sfl-analyze documentation`.
        class DocumentationWizard
          FLAGS = %w[pass1-only narrative resume store].freeze

          def run
            input = Gum.file(file: true, directory: true)
            return unless input

            output_dir = Prompts.blank_to_nil(
              Gum.input(value: "./output/latest", header: "Output directory")
            ) || "./output/latest"

            selected = Gum.choose(FLAGS, no_limit: true, header: "Toggle options (tab/space), enter to confirm") || []

            topics = Prompts.optional_int(
              Gum.input(placeholder: "(blank = skip topic modeling)", header: "Number of topics")
            )

            CLI.run_documentation(input, {
              output_dir:,
              pass1_only: selected.include?("pass1-only"),
              narrative: selected.include?("narrative"),
              resume: selected.include?("resume"),
              store: selected.include?("store"),
              topics:,
            })
          end
        end
      end
    end
  end
end
