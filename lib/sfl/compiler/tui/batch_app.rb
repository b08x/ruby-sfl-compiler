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
      # Analysis now runs in separate Sidekiq worker processes via
      # ConversationAnalysisWorkflow (Gush + Redis). This model never touches
      # Pipeline/spaCy/PyCall — it only polls the workflow's Redis state via
      # WorkflowPoller on each tick. This fixes the [BUG] Segmentation fault
      # that occurred when PyCall was called from inside a Bubbletea/Thread.new.
      class BatchApp
        include Bubbletea::Model

        class PollMessage < Bubbletea::Message
        end

        FailedMessage = Class.new(Bubbletea::Message) do
          attr_reader :error

          def initialize(error)
            super()
            @error = error
          end
        end

        POLL_INTERVAL = 0.5

        # @param workflow_id [String] Gush workflow UUID from
        #   ConversationAnalysisWorkflow.create(path).id
        # @param files [Array<String>] only used for display (header, file count)
        # @param options [Hash] :output_dir, :narrative — used by the caller
        #   (CLI) after Bubbletea.run returns, not by this model directly
        def initialize(workflow_id:, files:, width: 100, height: 30)
          @workflow_id = workflow_id
          @files = files
          @width = width
          @height = height

          @poller = WorkflowPoller.new(workflow_id)
          @current_file = files.first
          @current_turn = nil
          @log_lines = []
          @mood_tally = Hash.new(0)
          @process_tally = Hash.new(0)
          @tenor_sum = 0.0
          @modality_sum = 0.0
          @turn_count = 0
          @done = false
          @error = nil
          @result = nil
          @last_completed = 0
          @total = 0

          @log_viewport = Bubbles::Viewport.new(width: pane_width, height: height - 4)
          @log_viewport.style = Chat::Styles::VIEWPORT_BORDER
        end

        # @return [Hash, nil] the reduce job's output_payload; non-nil only
        #   after the workflow finishes. Caller (CLI) uses this to write reports.
        attr_reader :result

        def done? = @done

        def init
          [self, schedule_poll]
        end

        def update(message)
          case message
          when Bubbletea::KeyMessage
            handle_key(message)
          when PollMessage
            handle_poll
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

        private def handle_poll
          progress = @poller.poll
          @total = progress.total

          apply_progress(progress)

          if progress.status == :finished
            @done = true
            @result = progress.result
            [self, nil]
          elsif progress.status == :failed
            @done = true
            @error = RuntimeError.new("Workflow failed: #{progress.error || 'unknown job'}")
            [self, nil]
          else
            [self, schedule_poll]
          end
        end

        private def apply_progress(progress)
          newly_done = progress.completed - @last_completed
          @last_completed = progress.completed

          if newly_done.positive?
            @turn_count += newly_done
            append_log("  #{progress.completed}/#{progress.total} turns complete")
          end

          progress.running_jobs.each do |label|
            @current_turn = label
          end

          if progress.status == :finished && progress.result
            log_final_stats(progress.result)
          end
        end

        private def log_final_stats(result)
          append_log("")
          append_log("=== Complete ===")
          insight_count = result[:insights]&.size || 0
          append_log("#{result[:section_count] || result[:turn_count]} units — #{insight_count} insights")
        end

        private def append_log(line)
          @log_lines << line
          @log_viewport.content = @log_lines.join("\n")
          @log_viewport.goto_bottom
        end

        private def schedule_poll
          Bubbletea.tick(POLL_INTERVAL) { PollMessage.new }
        end

        private def header
          status_label = if @done
            @error ? "FAILED" : "DONE"
          else
            "running"
          end
          Chat::Styles::HEADER.render(
            "SFL Batch — #{File.basename(@current_file.to_s)} [#{status_label}]"
          )
        end

        private def footer
          return Chat::Styles::ERROR.render("Error: #{@error.message}") if @error
          return Chat::Styles::FOOTER.render("Done — q or ctrl+c to exit") if @done

          Chat::Styles::FOOTER.render("Sidekiq workers processing turns — q or ctrl+c to exit view")
        end

        private def left_pane
          lines = [
            "Current: #{@current_turn || '—'}",
            "Turns complete: #{@last_completed}/#{@total.positive? ? @total : '?'}",
            "",
            "Workflow: #{@workflow_id[0..7]}…",
          ]

          Lipgloss::Style.new
            .width(pane_width).height(@height - 4)
            .border(Lipgloss::ROUNDED_BORDER).padding(0, 1)
            .render(lines.join("\n"))
        end

        private def right_pane
          @log_viewport.view
        end

        private def pane_width
          (@width / 2) - 2
        end
      end
    end
  end
end
