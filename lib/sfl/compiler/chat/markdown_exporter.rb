# frozen_string_literal: true

module SFL
  module Compiler
    module Chat
      # Renders a Chat::Session's full transcript (questions, answers,
      # citations) as markdown, following the formatters/base_formatter
      # pattern (`result` here is a Session, not an AnalysisResult).
      class MarkdownExporter < Formatters::BaseFormatter
        def render
          lines = ["# SFL Chat Session", "", "_Exported #{Time.now}_", ""]

          result.turns.each_with_index do |turn, idx|
            lines.concat(render_turn(turn, idx))
          end

          lines.join("\n")
        end

        private def render_turn(turn, idx)
          lines = ["## Q#{idx + 1}: #{turn.query}", ""]
          lines << (turn.result.answer || "_No answer — insufficient evidence._")
          lines << ""

          unless turn.result.cited_clause_ids.empty?
            lines << "**Cited clauses:** #{turn.result.cited_clause_ids.join(', ')}"
            lines << ""
          end

          lines
        end
      end
    end
  end
end
