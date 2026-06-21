# frozen_string_literal: true

require_relative "tui/wizards/prompts"
require_relative "tui/wizards/conversation_wizard"
require_relative "tui/wizards/documentation_wizard"
require_relative "tui/wizards/context_wizard"
require_relative "tui/wizards/narrate_wizard"
require_relative "tui/menu"

module SFL
  module Compiler
    # Top-level interactive menu for `sfl-analyze tui`: a Gum.choose loop
    # that routes to a per-subcommand wizard (Gum file/input/choose prompts
    # collecting the same input+options shape CLI.parse builds) or to the
    # full-screen Chat TUI. Wizards call the existing CLI.run_* methods
    # directly rather than duplicating their Bootstrap/analyzer wiring.
    module TUI
    end
  end
end
