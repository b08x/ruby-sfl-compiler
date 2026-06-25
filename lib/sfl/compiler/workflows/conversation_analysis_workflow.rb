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
    # Topic modeling (the optional `topics:` pre-pass on
    # ConversationAnalyzer#analyze) is intentionally not supported here
    # yet — this workflow only covers the topics: nil path.
    class ConversationAnalysisWorkflow < Gush::Workflow
      def configure(jsonl_path)
        raw_turns = Analysis::ConversationAnalyzer.load_jsonl(jsonl_path)
        total = raw_turns.size

        turn_jobs = raw_turns.each_with_index.map do |turn_data, idx|
          run CompileTurnJob, params: { turn_data:, turn_id: idx + 1 }
        end

        run ReduceTurnsJob, params: { jsonl_path:, total: }, after: turn_jobs
      end
    end
  end
end
