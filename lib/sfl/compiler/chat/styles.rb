# frozen_string_literal: true

require "lipgloss"

module SFL
  module Compiler
    module Chat
      # Lipgloss style constants for the chat TUI. Kept separate so a
      # future palette change touches one file, not every screen.
      module Styles
        HEADER = Lipgloss::Style.new.bold(true).foreground("212")
        YOU = Lipgloss::Style.new.bold(true).foreground("39")
        ANSWER_LABEL = Lipgloss::Style.new.bold(true).foreground("82")
        CITATIONS = Lipgloss::Style.new.foreground("244").italic(true)
        FOOTER = Lipgloss::Style.new.foreground("241")
        ERROR = Lipgloss::Style.new.bold(true).foreground("196")
        VIEWPORT_BORDER = Lipgloss::Style.new.border(Lipgloss::ROUNDED_BORDER).padding(0, 1)
      end
    end
  end
end
