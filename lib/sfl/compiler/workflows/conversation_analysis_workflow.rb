# frozen_string_literal: true

# Zeitwerk autoloads this file the moment
# SFL::Compiler::ConversationAnalysisWorkflow is referenced, independently of
# whether Bootstrap.call(require_jobs: true) has run in this process — same
# rationale as CompileTurnJob/ReduceTurnsJob requiring "gush" directly,
# since subclassing Gush::Workflow below needs the constant to already
# exist.
require "gush"

module SFL
  module Compiler
    # Dynamic Gush workflow: fans out one CompileTurnJob per raw JSONL
    # turn (no dependency between them — they run in parallel across
    # Sidekiq workers), then fans into one ReduceTurnsJob that waits for
    # every turn job to finish before running cross-turn aggregation.
    #
    # `topics:` mirrors ConversationAnalyzer#analyze's own pre-pass: when
    # requested (and there are ≥3 turns — same threshold), a TopicModelJob
    # runs first, with no dependency on it (only needs raw turn text), and
    # every CompileTurnJob + ReduceTurnsJob then depends on it so they can
    # read its output from `payloads`.
    class ConversationAnalysisWorkflow < Gush::Workflow
      def configure(jsonl_path, topics: nil)
        raw_turns = Analysis::ConversationAnalyzer.load_jsonl(jsonl_path)
        total = raw_turns.size

        topic_job = run(TopicModelJob, params: { jsonl_path:, topics: }) if topics && total >= 3

        turn_jobs = raw_turns.each_with_index.map do |turn_data, idx|
          run_compile_turn_job(turn_data, idx + 1, topic_job)
        end

        reduce_deps = topic_job ? turn_jobs + [topic_job] : turn_jobs
        run ReduceTurnsJob, params: { jsonl_path:, total: }, after: reduce_deps
      end

      private def run_compile_turn_job(turn_data, turn_id, topic_job)
        params = { turn_data:, turn_id: }
        topic_job ? run(CompileTurnJob, params:, after: [topic_job]) : run(CompileTurnJob, params:)
      end
    end
  end
end
