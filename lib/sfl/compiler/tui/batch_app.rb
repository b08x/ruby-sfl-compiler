# frozen_string_literal: true

require "bubbletea"
require "lipgloss"
require "pastel"

module SFL
  module Compiler
    module TUI
      # Compact single-pane progress view for `sfl-analyze --live`.
      # Polls Gush/Redis state via WorkflowPoller — never touches Pipeline,
      # spaCy, or PyCall. PyCall is single-thread only; all analysis runs in
      # Sidekiq worker processes.
      class BatchApp
        include Bubbletea::Model

        class PollMessage < Bubbletea::Message; end

        FailedMessage = Class.new(Bubbletea::Message) do
          attr_reader :error
          def initialize(error) = super().tap { @error = error }
        end

        POLL_INTERVAL = 0.5
        BAR_WIDTH     = 32

        def initialize(workflow_id:, files:, width: 100, height: 30)
          @workflow_id    = workflow_id
          @files          = files
          @width          = width
          @height         = height
          @poller         = WorkflowPoller.new(workflow_id)
          @current_file   = files.first
          @current_turn   = nil
          @done           = false
          @error          = nil
          @result         = nil
          @last_completed = 0
          @total          = 0
          @started_at     = nil
          @pastel         = Pastel.new
        end

        attr_reader :result

        def done? = @done

        def init
          @started_at = Time.now
          [self, schedule_poll]
        end

        def update(message)
          case message
          when PollMessage    then handle_poll
          when FailedMessage  then @done = true; @error = message.error; [self, nil]
          when Bubbletea::KeyMessage then handle_key(message)
          else [self, nil]
          end
        end

        def view
          body = [
            "",
            "  #{progress_bar_line}",
            "",
            "  #{@pastel.dim('Section:')} #{@current_turn || @pastel.dim('waiting for workers…')}",
            "  #{summary_line}",
            ""
          ].join("\n")

          Lipgloss.join_vertical(Lipgloss::LEFT, header, body, footer)
        end

        private def handle_key(msg)
          msg.to_s =~ /ctrl\+c|^q$/ ? [self, Bubbletea.quit] : [self, nil]
        end

        private def handle_poll
          progress = @poller.poll
          @total   = progress.total

          apply_progress(progress)

          if progress.status == :finished
            @done   = true
            @result = progress.result
            [self, nil]
          elsif progress.status == :failed
            @done  = true
            @error = RuntimeError.new("Workflow failed: #{progress.error || 'unknown job'}")
            [self, nil]
          else
            [self, schedule_poll]
          end
        end

        private def apply_progress(progress)
          newly_done = progress.completed - @last_completed
          @last_completed = progress.completed
          @started_at ||= Time.now if newly_done.positive? && @last_completed == newly_done

          progress.running_jobs.each { |label| @current_turn = label }
        end

        private def schedule_poll
          Bubbletea.tick(POLL_INTERVAL) { PollMessage.new }
        end

        private def progress_bar_line
          return @pastel.dim("  #{BAR_WIDTH.times.map { '░' }.join}   0%") if @total.zero?

          ratio  = @last_completed.to_f / @total
          filled = (ratio * BAR_WIDTH).floor
          empty  = BAR_WIDTH - filled
          pct    = (ratio * 100).round

          bar = @pastel.green("█" * filled) + @pastel.dark("░" * empty)
          "#{bar}  #{pct}%  (#{@last_completed}/#{@total})  #{eta_string}"
        end

        private def eta_string
          return "" if @last_completed.zero? || @total.zero? || !@started_at
          elapsed = Time.now - @started_at
          return "" if elapsed < 1

          rate      = @last_completed / elapsed
          remaining = @total - @last_completed
          secs      = (remaining / rate).round

          return @pastel.dim("ETA: <1s") if secs <= 0
          @pastel.dim(secs < 60 ? "ETA: #{secs}s" : "ETA: #{secs / 60}m #{secs % 60}s")
        end

        private def summary_line
          if @done && @result && !@error
            count    = @result[:section_count] || @result[:turn_count] || 0
            insights = @result[:insights]&.size || 0
            coverage = @result.dig(:metadata, :annotation_coverage) || {}
            llm      = coverage[:llm] || 0
            fallback = coverage[:fallback] || 0
            "#{count} sections  ·  #{insights} insights  ·  #{llm} llm / #{fallback} fallback"
          elsif @done && @error
            ""
          else
            @pastel.dim("analysing…")
          end
        end

        private def header
          status = @done ? (@error ? @pastel.red("FAILED") : @pastel.green("DONE")) : @pastel.yellow("running")
          Chat::Styles::HEADER.render("SFL Batch — #{File.basename(@current_file.to_s)}  [#{status}]")
        end

        private def footer
          return Chat::Styles::ERROR.render("Error: #{@error.message}") if @error
          return Chat::Styles::FOOTER.render("Done  ·  q or ctrl+c to exit") if @done
          Chat::Styles::FOOTER.render("q / ctrl+c to exit")
        end
      end
    end
  end
end
