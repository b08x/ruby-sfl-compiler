# frozen_string_literal: true

require "bubbletea"
require "lipgloss"
require "pastel"

module SFL
  module Compiler
    module TUI
      # Compact bordered progress card for `sfl-analyze --live`.
      # Polls Gush/Redis state via WorkflowPoller — never touches Pipeline,
      # spaCy, or PyCall (all analysis runs in Sidekiq worker processes).
      class BatchApp
        include Bubbletea::Model

        class PollMessage < Bubbletea::Message; end

        FailedMessage = Class.new(Bubbletea::Message) do
          attr_reader :error

          def initialize(error) = super().tap { @error = error }
        end

        POLL_INTERVAL = 0.5
        BAR_WIDTH     = 36

        CARD_PADDING_H = 3  # left+right padding chars per side inside the card
        BORDER_CHARS   = 2  # one border char on each side

        def initialize(workflow_id:, files:, width: 100, height: 30)
          @workflow_id    = workflow_id
          @files          = files
          @width          = width
          @height         = height
          @poller         = WorkflowPoller.new(workflow_id)
          @current_file   = files.first
          @current_turn   = nil
          @chunk_progress = {}
          @done           = false
          @error          = nil
          @result         = nil
          @last_completed = 0
          @total          = 0
          @started_at     = nil
          @pastel         = Pastel.new
          @show_evidence  = false
        end

        attr_reader :result

        def done? = @done

        def init
          @started_at = Time.now
          [self, schedule_poll]
        end

        def update(message)
          case message
          when PollMessage           then handle_poll
          when FailedMessage         then @done = true; @error = message.error; [self, nil]
          when Bubbletea::KeyMessage then handle_key(message)
          else [self, nil]
          end
        end

        def view
          panes = [card]
          panes << EvidencePane.new(@result, width: @width, pastel: @pastel).render if show_evidence?
          Lipgloss.join_vertical(Lipgloss::LEFT, *panes, footer)
        end

        private def show_evidence? = @show_evidence && @done && !@error && @result

        private def handle_key(msg)
          case msg.to_s
          when /ctrl\+c|^q$/ then [self, Bubbletea.quit]
          when "e"           then @show_evidence = !@show_evidence; [self, nil]
          else                    [self, nil]
          end
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
          newly_done      = progress.completed - @last_completed
          @last_completed = progress.completed
          @started_at   ||= Time.now if newly_done.positive? && @last_completed == newly_done

          progress.running_jobs.each { |label| @current_turn = label }
          @chunk_progress = progress.chunk_progress || {}
        end

        private def schedule_poll
          Bubbletea.tick(POLL_INTERVAL) { PollMessage.new }
        end

        # ── Rendering ───────────────────────────────────────────────────

        private def card
          inner_w = @width - BORDER_CHARS - (CARD_PADDING_H * 2)

          body = [
            title_line(inner_w),
            "",
            progress_bar_line,
            time_line,
            "",
            current_section_line,
            "",
            completion_line,
          ].join("\n")

          Lipgloss::Style.new
            .border(Lipgloss::ROUNDED_BORDER)
            .border_foreground("62")
            .padding(1, CARD_PADDING_H)
            .width(@width - BORDER_CHARS)
            .render(body)
        end

        private def footer
          hint = +"  q / ctrl+c to exit"
          hint << "  ·  e evidence" if @done && !@error && @result
          Chat::Styles::FOOTER.render(hint)
        end

        # Title: "SFL Batch  ·  filename" left, "● status" right-aligned.
        private def title_line(inner_width)
          left  = "#{@pastel.bold('SFL Batch')}  #{@pastel.dim('·')}  " \
            "#{@pastel.cyan(File.basename(@current_file.to_s))}"
          right = status_dot
          gap   = [inner_width - visible_length(left) - visible_length(right), 1].max
          "#{left}#{' ' * gap}#{right}"
        end

        private def status_dot
          if @done
            @error ? @pastel.red("● failed") : @pastel.green("● done")
          else
            @pastel.yellow("● running")
          end
        end

        private def progress_bar_line
          return "#{@pastel.bright_black('░' * BAR_WIDTH)}   #{@pastel.dim('0%')}" if @total.zero?

          ratio  = @last_completed.to_f / @total
          filled = (ratio * BAR_WIDTH).floor
          pct    = (ratio * 100).round

          bar   = @pastel.green("█" * filled) +
            @pastel.bright_black("░" * (BAR_WIDTH - filled))
          count = @pastel.dim("#{@last_completed}/#{@total}")

          "#{bar}  #{@pastel.bold("#{pct}%")}  #{count}"
        end

        private def time_line
          return "" if @done

          parts = []
          if @started_at
            elapsed_s = (Time.now - @started_at).to_i
            parts << "elapsed #{format_duration(elapsed_s)}" if elapsed_s >= 1
          end
          if (eta = eta_seconds)
            parts << "ETA ~#{format_duration(eta)}"
          end
          return "" if parts.empty?

          @pastel.dim("  #{parts.join('  ·  ')}")
        end

        private def current_section_line
          if @done && !@error
            ""
          elsif @current_turn
            chunk_info = @chunk_progress[@current_turn]
            suffix = if chunk_info && chunk_info[:chunks_total].to_i.positive?
              done  = chunk_info[:chunks_done].to_i
              total = chunk_info[:chunks_total].to_i
              ratio = done.to_f / total
              mini_bar = ("█" * (ratio * 12).floor) + ("░" * (12 - (ratio * 12).floor))
              "  #{@pastel.dim(mini_bar)}  #{@pastel.dim("#{done}/#{total} chunks")}"
            else
              ""
            end
            "#{@pastel.cyan('→')}  #{@pastel.bold(@current_turn)}#{suffix}"
          else
            @pastel.dim("  waiting for workers…")
          end
        end

        private def completion_line
          return "" unless @done
          return Chat::Styles::ERROR.render(@error.message) if @error

          count    = @result[:section_count] || @result[:turn_count] || 0
          insights = @result[:insights]&.size || 0
          coverage = @result.dig(:metadata, :annotation_coverage) || {}
          llm      = coverage[:llm]      || 0
          fallback = coverage[:fallback] || 0

          [
            @pastel.green("✓"),
            "#{@pastel.bold(count.to_s)} #{@pastel.dim('sections')}",
            @pastel.dim("·"),
            "#{@pastel.bold(insights.to_s)} #{@pastel.dim('insights')}",
            @pastel.dim("·"),
            @pastel.dim("#{llm} llm · #{fallback} fallback"),
          ].join("  ")
        end

        # ── Helpers ─────────────────────────────────────────────────────

        # Strip ANSI escape codes to measure visible character width.
        private def visible_length(str)
          str.gsub(/\e\[[0-9;]*m/, "").length
        end

        private def eta_seconds
          return nil if @last_completed.zero? || @total.zero? || !@started_at

          elapsed = Time.now - @started_at
          return nil if elapsed < 2

          rate = @last_completed.to_f / elapsed
          ((@total - @last_completed) / rate).round
        end

        private def format_duration(secs)
          return "<1s" if secs <= 0

          (secs < 60) ? "#{secs}s" : "#{secs / 60}m #{secs % 60}s"
        end
      end
    end
  end
end
