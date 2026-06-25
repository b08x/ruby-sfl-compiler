# frozen_string_literal: true

# See compile_turn_job.rb's comment for why this require is direct,
# not deferred to Bootstrap's configure_jobs.
require "gush"

module SFL
  module Compiler
    # Topic-modeling pre-pass, run before the CompileTurnJob fan-out (no
    # dependency on it — only needs raw turn text). Mirrors
    # ConversationAnalyzer#analyze's inline topics: pre-pass (TopicModeler
    # fit over stub turns), but as its own Gush job so CompileTurnJob and
    # ReduceTurnsJob can depend on its output via `payloads` instead of
    # running TopicModeler.fit inline.
    class TopicModelJob < Gush::Job
      def perform
        jsonl_path = params.fetch(:jsonl_path)
        topics = params.fetch(:topics)

        raw_turns = Analysis::ConversationAnalyzer.load_jsonl(jsonl_path)
        stub_turns = raw_turns.each_with_index.map { |turn_data, idx| stub_turn(turn_data, idx) }

        modeler = Analysis::TopicModeler.new(k: topic_k(topics))
        modeler.fit(stub_turns)

        output(
          pre_turns: modeler.turns.map { |t| Types.dump(t) },
          topic_labels: modeler.topic_labels,
          topic_shifts: modeler.detect_topic_shifts
        )
      end

      private def stub_turn(turn_data, idx)
        Types::ConversationTurn.new(
          turn_id: idx + 1,
          speaker: turn_data[:name],
          timestamp: parse_timestamp(turn_data[:send_date]),
          message_text: turn_data[:mes],
          clauses: [],
          avg_tenor: 0.5,
          avg_modality: 0.5,
          dominant_mood: "declarative",
          process_types: {},
          participants: [],
          tenor_shift: nil,
          semantic_coherence_score: nil
        )
      end

      # `topics: 0` requests HDP (auto-discover the topic count, k: nil)
      # — same mapping ConversationAnalyzer#topic_k already uses.
      private def topic_k(topics)
        topics.zero? ? nil : topics
      end

      private def parse_timestamp(value)
        Time.parse(value.to_s)
      rescue ArgumentError
        Time.now
      end
    end
  end
end
