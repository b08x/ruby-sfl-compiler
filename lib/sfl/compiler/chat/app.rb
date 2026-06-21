# frozen_string_literal: true

require "bubbletea"
require "bubbles" # umbrella require — its internal load order requires cursor.rb before text_input.rb needs it
require "glamour"

module SFL
  module Compiler
    module Chat
      # Bubbletea full-screen chat: a scrollable transcript (Viewport) +
      # single-line input (TextInput), backed by a Chat::Session for RAG
      # retrieval/synthesis. `/export [path]` writes the transcript via
      # MarkdownExporter; `/quit` (or ctrl+c) exits.
      class App
        include Bubbletea::Model

        AnswerMessage = Class.new(Bubbletea::Message) do
          attr_reader :result

          def initialize(result)
            super()
            @result = result
          end
        end

        ErrorMessage = Class.new(Bubbletea::Message) do
          attr_reader :error

          def initialize(error)
            super()
            @error = error
          end
        end

        DEFAULT_EXPORT_PATH = "chat_session.md"

        def initialize(session:, width: 100, height: 24)
          @session = session
          @width = width
          @height = height
          @busy = false
          @lines = []

          @input = Bubbles::TextInput.new
          @input.prompt = "> "
          @input.placeholder = "Ask a question, or /export, /quit"
          @input.focus

          @viewport = Bubbles::Viewport.new(width:, height: height - 3)
          @viewport.style = Styles::VIEWPORT_BORDER

          @spinner = Bubbles::Spinner.new(spinner: Bubbles::Spinners::DOT)
        end

        def init
          [self, nil]
        end

        def update(message)
          case message
          when Bubbletea::KeyMessage
            handle_key(message)
          when AnswerMessage
            handle_answer(message.result)
          when ErrorMessage
            handle_error(message.error)
          when Bubbles::Spinner::TickMessage
            update_spinner(message)
          else
            [self, nil]
          end
        end

        def view
          Lipgloss.join_vertical(
            Lipgloss::LEFT,
            Styles::HEADER.render("SFL Chat — explore stored clauses"),
            @viewport.view,
            input_line,
            Styles::FOOTER.render("enter: ask   /export [path]: save transcript   /quit or ctrl+c: exit")
          )
        end

        private def handle_key(message)
          case message.to_s
          when "ctrl+c"
            return [self, Bubbletea.quit]
          end

          return [self, nil] if @busy

          return submit if message.enter?

          @input, command = @input.update(message)
          [self, command]
        end

        private def submit
          value = @input.value.strip
          return [self, nil] if value.empty?

          @input.reset
          return handle_command(value) if value.start_with?("/")

          append_line(Styles::YOU.render("You: ") + value)
          @busy = true

          [self, Bubbletea.batch(@spinner.tick, ask_command(value))]
        end

        private def handle_command(value)
          command, _sep, arg = value.partition(" ")
          case command
          when "/quit"
            [self, Bubbletea.quit]
          when "/export"
            export_session(arg.empty? ? DEFAULT_EXPORT_PATH : arg)
            [self, nil]
          else
            append_line(Styles::ERROR.render("Unknown command: #{command}"))
            [self, nil]
          end
        end

        private def export_session(path)
          MarkdownExporter.new(@session).write_to(path)
          append_line(Styles::FOOTER.render("Exported transcript to #{path}"))
        rescue => e
          append_line(Styles::ERROR.render("Export failed: #{e.message}"))
        end

        # Runs off the UI thread; the runner sends the returned Message
        # back into #update once @session.ask completes.
        private def ask_command(query)
          lambda do
            AnswerMessage.new(@session.ask(query))
          rescue => e
            ErrorMessage.new(e)
          end
        end

        private def handle_answer(result)
          @busy = false
          answer = Glamour.render(result.answer || "_No answer — insufficient evidence._")
          append_line(Styles::ANSWER_LABEL.render("Answer: ") + answer)
          unless result.cited_clause_ids.empty?
            append_line(Styles::CITATIONS.render("cited clauses: #{result.cited_clause_ids.join(', ')}"))
          end
          [self, nil]
        end

        private def handle_error(error)
          @busy = false
          append_line(Styles::ERROR.render("Error: #{error.message}"))
          [self, nil]
        end

        private def update_spinner(message)
          return [self, nil] unless @busy

          @spinner, command = @spinner.update(message)
          [self, command]
        end

        private def append_line(text)
          @lines << text
          @viewport.content = @lines.join("\n\n")
          @viewport.goto_bottom
        end

        private def input_line
          @busy ? "#{@spinner.view} thinking..." : @input.view
        end
      end
    end
  end
end
