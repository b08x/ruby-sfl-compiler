# frozen_string_literal: true

require "gum"
require "bubbletea"
require "dspy"

module SFL
  module Compiler
    module TUI
      # `sfl-analyze tui` entry point. A Gum.choose loop outside any
      # Bubbletea alt-screen — wizards run as plain sequential Gum
      # prompts + existing CLI.run_* stdout output; only "Chat with
      # results" hands off to the full-screen Bubbletea app.
      class Menu
        ACTIONS = {
          "Analyze a conversation" => :conversation,
          "Analyze documentation" => :documentation,
          "Query stored context" => :context,
          "Chat with results" => :chat,
          "Narrate a report" => :narrate,
          "Exit" => :exit,
        }.freeze

        # @param chat_session_builder [#call] builds a fresh Chat::Session
        #   (deferred so Bootstrap/DB/LLM wiring only happens if chosen)
        def initialize(chat_session_builder:)
          @chat_session_builder = chat_session_builder
        end

        def run
          loop do
            choice = Gum.choose(ACTIONS.keys, header: "sfl-analyze tui")
            break if choice.nil?

            action = ACTIONS.fetch(choice)
            break if action == :exit

            dispatch(action)
          end
        end

        private def dispatch(action)
          case action
          when :conversation then safe_run { Wizards::ConversationWizard.new.run }
          when :documentation then safe_run { Wizards::DocumentationWizard.new.run }
          when :context then safe_run { Wizards::ContextWizard.new.run }
          when :narrate then safe_run { Wizards::NarrateWizard.new.run }
          when :chat then Bubbletea.run(Chat::App.new(session: @chat_session_builder.call))
          end
        end

        private def safe_run
          yield
        rescue Error, DSPy::LM::AdapterError => e
          warn "[ERROR] #{e.message}"
        ensure
          Gum.input(header: "Press enter to return to the menu")
        end
      end
    end
  end
end
