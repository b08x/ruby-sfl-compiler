#!/usr/bin/env ruby
# frozen_string_literal: true

# One-window Genie-compression worker for rolling_synthesis_validation.rb,
# run as its own OS process per window for the same reason
# process_one_pdf_section.rb is: DSPy/OpenRouter calls were observed to
# hang past every configured timeout during this validation, and
# per-process `timeout N` isolation is the only thing that reliably
# recovers from it.
#
# Usage: bundle exec ruby experiments/compress_one_window.rb <window_index>

require "sfl-compiler"

WINDOW_SIZE = 15
WORKFLOW_ID = "rolling-synthesis-validation-final"

window_index = ARGV.fetch(0).to_i

ctx = SFL::Compiler::Bootstrap.call(require_db: true, require_llm: true, load_dotenv: true)

ids = ctx.db[:clauses].where(source_type: "vault_pdf").order(:created_at).select_map(:external_id)
window_ids = ids.each_slice(WINDOW_SIZE).to_a.fetch(window_index)

job = SFL::Compiler::IntermediateGenieJob.new(params: { clause_ids: window_ids, workflow_id: WORKFLOW_ID })
job.perform

puts "window #{window_index}: compressed #{window_ids.size} clauses -> summary #{job.output_payload[:summary_id]} " \
     "(clause_count=#{job.output_payload[:clause_count]})"
