# frozen_string_literal: true

require "gum"

module SFL
  module Compiler
    module TUI
      module Wizards
        # Gum-prompt front end for `sfl-analyze conversation`. Collects
        # the same input+options CLI.parse_conversation_options would,
        # then calls CLI.run_conversation directly.
        class ConversationWizard
          FLAGS = %w[pass1-only narrative resume].freeze

          def run
            input = Gum.file(file: true, directory: false)
            return unless input

            output_dir = Prompts.blank_to_nil(
              Gum.input(value: "./output/latest", header: "Output directory")
            ) || "./output/latest"

            selected = Gum.choose(FLAGS, no_limit: true, header: "Toggle options (tab/space), enter to confirm") || []

            topics = Prompts.optional_int(
              Gum.input(placeholder: "(blank = skip topic modeling)", header: "Number of topics")
            )

            CLI.run_conversation(input, {
              output_dir:,
              pass1_only: selected.include?("pass1-only"),
              narrative: selected.include?("narrative"),
              resume: selected.include?("resume"),
              topics:,
            })
          end
        end
      end
    end
  end
end
