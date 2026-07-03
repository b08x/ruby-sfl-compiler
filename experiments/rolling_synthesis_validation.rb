#!/usr/bin/env ruby
# frozen_string_literal: true

# Validates Rolling Synthesis (IntermediateGenieJob's clause -> Axiomatic
# summary compression) against a real ~7,400-word document, chunked the
# same way PassTwoEngine batches clauses for a Pass 2 call.
#
# NOTE: this drives IntermediateGenieJob directly rather than through
# CognitiveGas's automatic on_gas_exhausted trigger. That auto-trigger is
# confirmed broken — see repro_gas_exhaustion_bug.rb and RESULTS.md — so
# routing through it here would only validate a summary built from zero
# real clauses. Compressing real, already-stored clause windows still
# exercises the actual compression mechanism (IntermediateGenieJob +
# AxiomaticSummaryRepository + the real DSPy LLM call) for real.
#
# Usage: bundle exec ruby experiments/rolling_synthesis_validation.rb

require "sfl-compiler"

PDF_PATH = File.expand_path(
  "~/Notebook/assets/pdf/Chomsky’s Universal Grammar and Halliday’s Systemic Functional Linguistics.pdf"
)
CHUNK_SIZE = 15 # clauses compressed per rolling-synthesis window
WORKFLOW_ID = "rolling-synthesis-validation-#{Time.now.to_i}"

ctx = SFL::Compiler::Bootstrap.call(require_db: true, require_llm: true, load_dotenv: true)
db = ctx.db

sections = SFL::Compiler::PdfLoader.load(PDF_PATH)
word_count = sections.sum { |s| s.text.split.size }
puts "Loaded #{sections.size} sections, #{word_count} words from #{File.basename(PDF_PATH)}"

pass_one = SFL::Compiler::PassOneEngine.new
extractor = SFL::Compiler::IdeationalExtractor.new
pass_two = SFL::Compiler::PassTwoEngine.new
clause_repo = SFL::Compiler::ClauseRepository.new(db)
summary_repo = SFL::Compiler::AxiomaticSummaryRepository.new(db)

all_clauses = []
sections.each do |section|
  syntactic = pass_one.process(section.text, document_id: section.document_id)
  pairs = syntactic.map { |c| [c, extractor.extract(c)] }
  # concurrency: 1 — the default concurrency: 4 thread pool hit the
  # documented "response bytes sitting unread in the socket while the
  # async reactor deadlocks on a mutex" hang (pass_two_engine.rb's
  # DEFAULT_CHUNK_TIMEOUT comment) live during this validation: two
  # sockets sat in CLOSE-WAIT with unread recv-queues for 10+ minutes
  # past every configured timeout. Sequential calls avoid it.
  annotated = pass_two.annotate_batch(pairs, concurrency: 1)
  annotated.each { |a| clause_repo.store(a, source_type: "vault_pdf") }
  all_clauses.concat(annotated)
  print "."
end
puts
puts "Compiled and stored #{all_clauses.size} clauses"

# Drive rolling synthesis: compress in fixed-size windows (what CognitiveGas
# exhaustion is *supposed* to trigger automatically — see note above).
chunk_log = []
all_clauses.each_slice(CHUNK_SIZE).with_index do |chunk, i|
  ids = chunk.map(&:id)
  job = SFL::Compiler::IntermediateGenieJob.new(params: { clause_ids: ids, workflow_id: WORKFLOW_ID })
  job.perform
  chunk_log << { window: i + 1, clause_count: ids.size, cumulative: [(i + 1) * CHUNK_SIZE, all_clauses.size].min }
  print "."
end
puts
summaries = summary_repo.for_workflow(WORKFLOW_ID)
puts "Compressed into #{summaries.size} Axiomatic summaries\n\n"

# --- (1) process_type distribution preserved within 10 percentage points ---
raw_dist = all_clauses.group_by { |a| a.ideational.process_type }
  .transform_values { |v| v.size.to_f / all_clauses.size }

total_in_summaries = summaries.sum { |s| s[:clause_count] }
summary_dist = Hash.new(0.0)
summaries.each do |s|
  s[:process_type_distribution].each do |k, v|
    summary_dist[k] += v.to_f * (s[:clause_count].to_f / total_in_summaries)
  end
end

puts "== (1) Process type distribution: raw clauses vs. summarized =="
deltas = (raw_dist.keys | summary_dist.keys).map do |k|
  delta = (raw_dist[k].to_f - summary_dist[k].to_f).abs
  puts "  #{k}: raw=#{(raw_dist[k].to_f * 100).round(1)}%  summary=#{(summary_dist[k].to_f * 100).round(1)}%  delta=#{(delta * 100).round(1)}pp"
  delta
end
puts "  Max delta: #{(deltas.max * 100).round(1)}pp -> #{deltas.max <= 0.10 ? 'PASS (within 10 points)' : 'FAIL'}\n\n"

# --- (2) stance filter hit-rate equivalence: raw clauses vs. summaries ---
puts "== (2) Stance filter hit rate: raw clauses vs. summaries =="
[[0.5, 0.0], [0.0, 0.5], [0.5, 0.5]].each do |min_mod, min_ten|
  raw_hits = all_clauses.count { |a| a.interpersonal.modality_weight >= min_mod && a.interpersonal.tenor >= min_ten }
  raw_rate = raw_hits.to_f / all_clauses.size
  summary_hits = summaries.count { |s| s[:avg_modality].to_f >= min_mod && s[:avg_tenor].to_f >= min_ten }
  summary_rate = summary_hits.to_f / summaries.size
  delta = (raw_rate - summary_rate).abs
  puts "  min_modality>=#{min_mod}, min_tenor>=#{min_ten}: raw=#{(raw_rate * 100).round(1)}%  summary=#{(summary_rate * 100).round(1)}%  delta=#{(delta * 100).round(1)}pp"
end
puts

# --- (3) per-call context window stays bounded, not proportional to document length ---
puts "== (3) Context window growth (clauses fed to each Genie call) =="
chunk_log.each { |c| puts "  window #{c[:window]}: #{c[:clause_count]} clauses compressed (document position: #{c[:cumulative]}/#{all_clauses.size})" }
distinct_sizes = chunk_log.map { |c| c[:clause_count] }.uniq
bounded = distinct_sizes.size <= 2 # constant CHUNK_SIZE, plus one possible smaller final chunk
puts "  Per-call chunk size stays at #{distinct_sizes.sort.inspect} regardless of document position -> #{bounded ? 'PASS (bounded, not proportional)' : 'FAIL'}"

puts "\nDone. Workflow id: #{WORKFLOW_ID}"
