# frozen_string_literal: true

require "gush"

module SFL
  module Compiler
    # One section's Pass 1 + Pass 2 compilation, run inside a Gush/Sidekiq
    # worker process. Mirrors CompileTurnJob's structure exactly, with
    # section_datum replacing turn_data.
    #
    # section_datum keys (symbolized by Gush's JSON round-trip, matching
    # CompileTurnJob's turn_data[:name] pattern):
    #   :text, :heading, :file_id, :document_id, :mtime, :pdf_chunk
    class CompileSectionJob < Gush::Job
      def perform
        datum      = params.fetch(:section_datum)
        section_id = params.fetch(:section_id)
        store      = params.fetch(:store, false)
        pre_turn   = pre_turn_for(section_id)

        clauses = pipeline.compile(datum[:text], **compile_kwargs(datum, store, pre_turn))

        avg_tenor    = mean(clauses.map { |c| c.interpersonal.tenor })
        avg_modality = mean(clauses.map { |c| c.interpersonal.modality_weight })
        mood_counts  = clauses.map { |c| c.interpersonal.mood }.tally

        turn = Types::ConversationTurn.new(
          turn_id:   section_id,
          speaker:   datum[:heading] || datum[:file_id],
          timestamp: parse_mtime(datum[:mtime]),
          message_text: datum[:text],
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

      private def compile_kwargs(datum, store, pre_turn)
        kwargs = { document_id: datum[:document_id], store:, embed: store, resume: false }
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

      private def pre_turn_for(section_id)
        topic_payload&.[](:pre_turns)&.find { |t| t[:turn_id] == section_id }
      end

      private def topic_labels
        @topic_labels ||= (topic_payload&.[](:topic_labels) || {}).transform_keys { |k| k.to_s.to_i }
      end

      private def topic_payload
        @topic_payload ||= Array(payloads).find { |p| p[:class] == TopicModelJob.to_s }&.fetch(:output)
      end

      private def pipeline
        @pipeline ||= begin
          ctx = Bootstrap.call(require_db: true, require_llm: true, require_observability: true)
          Pipeline.new(db: ctx.db, spacy_model: ctx.config.spacy_model)
        end
      end

      private def mean(values)
        return 0.0 if values.empty?

        values.sum / values.size.to_f
      end

      private def parse_mtime(value)
        Time.parse(value.to_s)
      rescue ArgumentError
        Time.now
      end
    end
  end
end
