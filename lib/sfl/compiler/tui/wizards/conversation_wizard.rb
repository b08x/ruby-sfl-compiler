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
            # directory: false is also the gem's documented default — kept
            # implicit because passing it explicitly hits a bug in the gum
            # gem (0.3.2): its flag_supports_negation? allowlist claims
            # `file`'s directory/file/all flags support --no-<flag>, but
            # the actual installed gum CLI (v0.17.0, verified via
            # `gum file --help`) only negates --permissions/--size —
            # passing directory: false emits --no-directory, which the
            # real binary rejects with "unknown flag --no-directory".
            input = Gum.file(file: true)
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
