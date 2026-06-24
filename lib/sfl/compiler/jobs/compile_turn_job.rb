# frozen_string_literal: true

# Zeitwerk autoloads this file the moment SFL::Compiler::CompileTurnJob is
# referenced, which happens independently of whether Bootstrap.call(
# require_jobs: true) has run in this process. Bootstrap's own `require
# "gush"` (in #configure_jobs) is too late for this class definition, since
# subclassing Gush::Job below needs the constant to already exist — so this
# file requires it directly, the same way any other autoloaded class that
# subclasses a third-party gem class would.
require "gush"

module SFL
  module Compiler
    # One turn's Pass 1 + Pass 2 compilation, run inside a Gush/Sidekiq
    # worker process. Each worker is a separate OS process with its own
    # Python interpreter, so spaCy/PyCall (called transitively via
    # Pipeline#compile -> PassOneEngine) never shares state across
    # threads — unlike TUI::BatchApp's broken --live view, which ran the
    # same call inside a Ruby Thread sharing one process's PyCall state.
    class CompileTurnJob < Gush::Job
      def perform
        turn_data = params.fetch(:turn_data)
        turn_id = params.fetch(:turn_id)

        clauses = pipeline.compile(
          turn_data[:mes],
          document_id: "turn-#{turn_id}",
          store: false,
          embed: false,
          resume: false
        )

        avg_tenor = mean(clauses.map { |c| c.interpersonal.tenor })
        avg_modality = mean(clauses.map { |c| c.interpersonal.modality_weight })
        mood_counts = clauses.map { |c| c.interpersonal.mood }.tally

        turn = Types::ConversationTurn.new(
          turn_id:,
          speaker: turn_data[:name],
          timestamp: parse_timestamp(turn_data[:send_date]),
          message_text: turn_data[:mes],
          clauses:,
          avg_tenor:,
          avg_modality:,
          dominant_mood: mood_counts.max_by { |_, count| count }&.first || "declarative",
          process_types: clauses.map { |c| c.ideational.process_type }.tally,
          participants: clauses.flat_map { |c| c.ideational.participants.map(&:text) }.uniq,
          tenor_shift: nil
        )

        output(Types.dump(turn))
      end

      private def pipeline
        @pipeline ||= begin
          ctx = Bootstrap.call(require_db: true, require_llm: true, require_observability: false)
          Pipeline.new(db: ctx.db, spacy_model: ctx.config.spacy_model)
        end
      end

      private def mean(values)
        return 0.0 if values.empty?

        values.sum / values.size.to_f
      end

      private def parse_timestamp(value)
        Time.parse(value.to_s)
      rescue ArgumentError
        Time.now
      end
    end
  end
end
