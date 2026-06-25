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
        pre_turn = pre_turn_for(turn_id)

        clauses = pipeline.compile(turn_data[:mes], **compile_kwargs(turn_id, pre_turn))

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
          tenor_shift: nil,
          topic_distribution: pre_turn&.[](:topic_distribution),
          dominant_topic: pre_turn&.[](:dominant_topic),
          semantic_coherence_score: pre_turn&.[](:semantic_coherence_score)
        )

        output(Types.dump(turn))
      end

      # Same conditional-kwargs shape as ConversationAnalyzer#compile_clauses
      # — only forwarded when present, so a run with no TopicModelJob
      # dependency calls Pipeline#compile exactly as it did before this
      # job supported topic modeling at all.
      private def compile_kwargs(turn_id, pre_turn)
        kwargs = { document_id: "turn-#{turn_id}", store: false, embed: false, resume: false }
        topic = topic_info_for(pre_turn)
        kwargs[:topic] = topic unless topic.nil?
        score = pre_turn&.[](:semantic_coherence_score)
        kwargs[:semantic_coherence_score] = score unless score.nil?
        kwargs
      end

      private def topic_info_for(pre_turn)
        dominant_topic = pre_turn&.[](:dominant_topic)
        return nil unless dominant_topic

        { id: dominant_topic, label: topic_labels[dominant_topic]&.first }
      end

      private def pre_turn_for(turn_id)
        topic_payload&.[](:pre_turns)&.find { |t| t[:turn_id] == turn_id }
      end

      # Topic ids round-trip through Gush's JSON-backed payloads as hash
      # *keys*, which JSON always serializes as strings — unlike values
      # (e.g. dominant_topic itself), which stay Integers. Restore the
      # Integer keys TopicModeler's own topic_labels uses.
      private def topic_labels
        @topic_labels ||= (topic_payload&.[](:topic_labels) || {}).transform_keys { |k| k.to_s.to_i }
      end

      private def topic_payload
        @topic_payload ||= Array(payloads).find { |p| p[:class] == TopicModelJob.to_s }&.fetch(:output)
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
