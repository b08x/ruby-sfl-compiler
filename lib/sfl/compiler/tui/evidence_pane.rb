# frozen_string_literal: true

require "lipgloss"
require "pastel"

module SFL
  module Compiler
    module TUI
      # Post-run evidence/provenance card for `sfl-analyze --live`, toggled
      # with `e` once the workflow finishes. Renders only what the pipeline
      # actually measured — categorical provenance (annotation_source) and
      # verified reasoning traces — never a synthesized "parser confidence"
      # scalar the system doesn't compute.
      #
      # Pure renderer: consumes the reduce job's output payload hash (the
      # same one BatchApp already holds as @result) and returns a string.
      # No Bubbletea, no Redis, no state — testable with a plain hash.
      class EvidencePane
        BAR_WIDTH   = 36
        MAX_FLAGGED = 6
        MAX_RULES   = 3

        SOURCE_ORDER = %w[llm fallback stub].freeze

        def initialize(result, width: 100, pastel: Pastel.new)
          @result = result || {}
          @width  = width
          @pastel = pastel
        end

        def render
          body = if clauses.empty?
            @pastel.dim("no clause data in payload — older reduce output; re-run to regenerate")
          else
            [
              header_line,
              "",
              coverage_bar,
              "",
              *flagged_section,
              *trace_section,
            ].join("\n")
          end

          Lipgloss::Style.new
            .border(Lipgloss::ROUNDED_BORDER)
            .border_foreground("62")
            .padding(1, BatchApp::CARD_PADDING_H)
            .width(@width - BatchApp::BORDER_CHARS)
            .render(body)
        end

        private def clauses
          @clauses ||= Array(@result[:turns]).flat_map { |t| Array(t[:clauses]) }
        end

        private def interpersonal(clause) = clause[:interpersonal] || {}

        private def source_counts
          @source_counts ||= clauses.group_by { |c| interpersonal(c)[:annotation_source].to_s }
            .transform_values(&:size)
        end

        private def header_line
          total = clauses.size
          "#{@pastel.bold('Evidence')}  #{@pastel.dim("· #{total} clauses · provenance + reasoning traces")}"
        end

        # Segmented provenance bar: llm green, fallback yellow, stub dim —
        # the honest analogue of the vision doc's "confidence heatmap".
        private def coverage_bar
          total = clauses.size
          segments = SOURCE_ORDER.map { |src| [src, source_counts.fetch(src, 0)] }

          widths = proportional_widths(segments.map(&:last), total)
          bar = segments.each_with_index.map do |(src, _), i|
            colorize_source(src, "█" * widths[i])
          end.join

          legend = segments.reject { |_, n| n.zero? }.map do |src, n|
            colorize_source(src, "#{src} #{n}")
          end.join(@pastel.dim("  ·  "))

          "#{bar}  #{legend}"
        end

        # Clauses that would land in a future review queue: everything the
        # LLM did not annotate (fallback defaults, pass-1-only stubs).
        private def flagged_section
          flagged = clauses.reject { |c| interpersonal(c)[:annotation_source].to_s == "llm" }
          return [] if flagged.empty?

          lines = flagged.first(MAX_FLAGGED).map do |c|
            ip  = interpersonal(c)
            tag = colorize_source(ip[:annotation_source].to_s, "[#{ip[:annotation_source]}]")
            "  #{tag} #{truncate(c[:text].to_s, @width - 24)}"
          end
          overflow = flagged.size - MAX_FLAGGED
          lines << @pastel.dim("  … #{overflow} more") if overflow.positive?

          ["#{@pastel.bold('Needs attention')}  #{@pastel.dim("· #{flagged.size} non-llm clauses")}", *lines, ""]
        end

        private def trace_section
          traced = clauses.filter_map { |c| interpersonal(c)[:reasoning_trace] }
          return [@pastel.dim("no reasoning traces in this run")] if traced.empty?

          confidences = traced.filter_map { |t| t[:confidence] }
          avg = confidences.empty? ? nil : (confidences.sum / confidences.size)

          rules = traced.map { |t| t[:inference_rule].to_s }.tally
            .sort_by { |_, n| -n }.first(MAX_RULES)
          rule_list = rules.map { |rule, n| "#{truncate(rule, 40)} ×#{n}" }.join(@pastel.dim("  ·  "))

          summary = "#{traced.size}/#{clauses.size} clauses traced"
          summary << "  ·  avg confidence #{format('%.2f', avg)}" if avg
          [
            "#{@pastel.bold('Reasoning traces')}  #{@pastel.dim("· #{summary}")}",
            "  #{@pastel.dim(rule_list)}",
          ]
        end

        # Integer bar widths that always sum to BAR_WIDTH, with any zero
        # count contributing zero cells (no phantom segment).
        private def proportional_widths(counts, total)
          return [0] * counts.size if total.zero?

          exact = counts.map { |n| n.to_f / total * BAR_WIDTH }
          widths = exact.map(&:floor)
          # distribute the rounding remainder to the largest fractional parts
          (BAR_WIDTH - widths.sum).times do
            i = exact.each_with_index.max_by { |x, j| x - widths[j] }.last
            widths[i] += 1
          end
          widths
        end

        private def colorize_source(source, str)
          case source
          when "llm"      then @pastel.green(str)
          when "fallback" then @pastel.yellow(str)
          else                 @pastel.bright_black(str)
          end
        end

        private def truncate(str, max)
          (str.length > max) ? "#{str[0, [max - 1, 1].max]}…" : str
        end
      end
    end
  end
end
