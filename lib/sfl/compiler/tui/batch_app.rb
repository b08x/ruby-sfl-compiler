# frozen_string_literal: true

require "bubbletea"
require "bubbles"
require "lipgloss"

module SFL
  module Compiler
    module TUI
      # Live split-pane progress view for `sfl-analyze conversation --live`.
      # Left pane: running SFL stats (mood/process-type distribution, avg
      # tenor/modality) recomputed after each completed turn. Right pane:
      # the same turn-by-turn log the plain CLI prints.
      #
      # The analysis itself runs in a background thread — Bubbletea's own
      # Proc-command threading (confirmed live against the installed gem's
      # runner.rb: a Proc command genuinely runs via Thread.new). Bubbletea
      # exposes no documented API for a background thread to push a
      # Message into a *running* program directly, so ConversationAnalyzer's
      # on_turn_start/on_progress callbacks push onto a thread-safe Queue
      # instead, which this Model drains on a fast recurring tick — the
      # same hand-off shape Bubbles::Spinner already uses for its own
      # tick-driven animation, just carrying progress data instead.
      class BatchApp
        include Bubbletea::Model

        class PollMessage < Bubbletea::Message
        end

        class DoneMessage < Bubbletea::Message
        end
        FailedMessage = Class.new(Bubbletea::Message) do
          attr_reader :error

          def initialize(error)
            super()
            @error = error
          end
        end

        POLL_INTERVAL = 0.1

        # @param pipeline [Pipeline]
        # @param files [Array<String>] one or more .jsonl paths
        # @param pass_one_only [Boolean]
        # @param topics [Integer, nil]
        # @param resume [Boolean]
        def initialize(pipeline:, files:, pass_one_only: false, topics: nil, resume: false, width: 100, height: 30)
          @pipeline = pipeline
          @files = files
          @pass_one_only = pass_one_only
          @topics = topics
          @resume = resume
          @width = width
          @height = height

          @queue = Queue.new
          @results = []
          @log_lines = []
          @current_file_index = 0
          @current_file = files.first
          @current_turn = nil
          @mood_tally = Hash.new(0)
          @process_tally = Hash.new(0)
          @tenor_sum = 0.0
          @modality_sum = 0.0
          @turn_count = 0
          @done = false
          @error = nil

          @log_viewport = Bubbles::Viewport.new(width: pane_width, height: height - 4)
          @log_viewport.style = Chat::Styles::VIEWPORT_BORDER
        end

        # @return [Array<Types::AnalysisResult>] available once #done? is true
        attr_reader :results

        def done? = @done

        def init
          [self, Bubbletea.batch(schedule_poll, run_analysis)]
        end

        def update(message)
          case message
          when Bubbletea::KeyMessage
            handle_key(message)
          when PollMessage
            drain_queue
            [self, @done ? nil : schedule_poll]
          when DoneMessage
            @done = true
            [self, nil]
          when FailedMessage
            @done = true
            @error = message.error
            [self, nil]
          else
            [self, nil]
          end
        end

        def view
          Lipgloss.join_vertical(
            Lipgloss::LEFT,
            header,
            Lipgloss.join_horizontal(Lipgloss::TOP, left_pane, right_pane),
            footer
          )
        end

        private def handle_key(message)
          case message.to_s
          when "ctrl+c", "q"
            [self, Bubbletea.quit]
          else
            [self, nil]
          end
        end

        private def schedule_poll
          Bubbletea.tick(POLL_INTERVAL) { PollMessage.new }
        end

        # Runs off the UI thread. ConversationAnalyzer#analyze itself is
        # unmodified — on_turn_start/on_progress just enqueue instead of
        # printing.
        private def run_analysis
          lambda do
            analyzer = Analysis::ConversationAnalyzer.new(
              pipeline: @pipeline,
              pass_one_only: @pass_one_only,
              on_turn_start: -> (event) { @queue << event.merge(kind: :start) },
              on_progress: -> (event) { @queue << event.merge(kind: :progress) }
            )

            @files.each_with_index do |file, index|
              @queue << { kind: :file, index:, file: }
              @results << analyzer.analyze(file, topics: @topics, resume: @resume)
            end

            DoneMessage.new
          rescue => e
            FailedMessage.new(e)
          end
        end

        private def drain_queue
          until @queue.empty?
            event = @queue.pop(true)
            handle_event(event)
          end

          @log_viewport.content = @log_lines.join("\n")
          @log_viewport.goto_bottom
        rescue ThreadError
          nil # queue went empty between #empty? and #pop(true) -- nothing left to drain
        end

        private def handle_event(event)
          case event[:kind]
          when :file
            @current_file_index = event[:index]
            @current_file = event[:file]
            @log_lines << Chat::Styles::HEADER.render("=== #{File.basename(event[:file])} ===")
          when :start
            @current_turn = "#{event[:turn_id]}/#{event[:total]} (#{event[:speaker]})"
          when :progress
            record_stats(event[:turn])
            label = event[:defaulted].zero? ? "OK" : "#{event[:defaulted]}/#{event[:clause_count]} DEFAULTED"
            @log_lines << "  #{event[:turn_id]}/#{event[:total]} (#{event[:speaker]}) #{event[:elapsed]}s [#{label}]"
          end
        end

        private def record_stats(turn)
          return unless turn

          @turn_count += 1
          @mood_tally[turn.dominant_mood] += 1
          turn.process_types.each { |type, count| @process_tally[type] += count }
          @tenor_sum += turn.avg_tenor
          @modality_sum += turn.avg_modality
        end

        private def header
          status = if @done
            @error ? "FAILED" : "DONE"
          else
            "running"
          end
          file_progress = (@files.size > 1) ? " — file #{@current_file_index + 1}/#{@files.size}" : ""
          Chat::Styles::HEADER.render("SFL Batch — #{File.basename(@current_file.to_s)}#{file_progress} [#{status}]")
        end

        private def footer
          return Chat::Styles::ERROR.render("Error: #{@error.message}") if @error
          return Chat::Styles::FOOTER.render("Done — q or ctrl+c to exit") if @done

          Chat::Styles::FOOTER.render("q or ctrl+c to exit (analysis keeps running in the background)")
        end

        private def left_pane
          lines = [
            "Current: #{@current_turn || '—'}",
            "Turns analyzed: #{@turn_count}",
            "",
            "Avg tenor:    #{avg(@tenor_sum).round(3)}",
            "Avg modality: #{avg(@modality_sum).round(3)}",
          ]
          lines.concat(tally_lines("Mood distribution:", @mood_tally))
          lines.concat(tally_lines("Process types:", @process_tally))

          Lipgloss::Style.new
            .width(pane_width).height(@height - 4)
            .border(Lipgloss::ROUNDED_BORDER).padding(0, 1)
            .render(lines.join("\n"))
        end

        private def tally_lines(title, tally)
          ["", title, *tally.sort_by { |_, c| -c }.map { |k, count| "  #{k}: #{count}" }]
        end

        private def right_pane
          @log_viewport.view
        end

        private def pane_width
          (@width / 2) - 2
        end

        private def avg(sum)
          return 0.0 if @turn_count.zero?

          sum / @turn_count.to_f
        end
      end
    end
  end
end
