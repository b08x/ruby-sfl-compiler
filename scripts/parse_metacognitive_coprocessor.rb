#!/usr/bin/env ruby
# frozen_string_literal: true

# parse_metacognitive_coprocessor.rb
#
# Runs all linted source documents from the Metacognitive Coprocessor
# NotebookLM notebook through the two-pass SFL compiler pipeline.
#
# Each source file is chunked by heading via MarkdownLoader, producing
# section-granular document_ids ("lsd-brain-network-collapse#the-tldr")
# before spaCy tokenisation — keeping markdown syntax noise out of Pass 1.
#
# Usage:
#   cd /home/b08x/WorkspaceV3/sfl-compiler
#   bundle exec ruby scripts/parse_metacognitive_coprocessor.rb
#
#   # Pass 1 only (cheaper — no LLM calls):
#   PASS=1 bundle exec ruby scripts/parse_metacognitive_coprocessor.rb
#
#   # Dry run — print sections without compiling:
#   DRY_RUN=1 bundle exec ruby scripts/parse_metacognitive_coprocessor.rb
#
#   # Single file:
#   FILE=lsd-brain-network-collapse.md bundle exec ruby scripts/parse_metacognitive_coprocessor.rb

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "sfl/compiler"

# ── Configuration ─────────────────────────────────────────────────────────────

NOTEBOOK_SOURCES = File.expand_path(
  "../../../Notebook/NotebookLM/metacognitive-coprocessor/Sources",
  __dir__
)

NOTEBOOK_REPORTS = File.expand_path(
  "../../../Notebook/NotebookLM/metacognitive-coprocessor/Reports",
  __dir__
)

# Source docs ordered large → small so long-running files fail fast if broken
SOURCE_FILES = %w[
  lsd-brain-network-collapse.md
  analyzing-complex-thinkers-architecturally.md
  vygotsky-chomsky-llm-geometry-gdoc.md
  analyzing-cognitive-musical-architectures.md
  branch-lsd-brain-network-collapse.md
  ruby-pic-architectural-mapping.md
  vygotsky-a-plan.md
  vygotsky-chomsky-llm-geometry-note.md
  researching-a-list-of-names.md
  research-plan-generated.md
  list-of-names-research-plan.md
].map { |f| File.join(NOTEBOOK_SOURCES, f) }

REPORT_FILES = %w[
  architectural-cognitive-musical-systems-study-guide.md
  architectural-specification-sfl-pipeline.md
  strategy-guidebook.md
  systems-architecture-study-guide.md
].map { |f| File.join(NOTEBOOK_REPORTS, f) }

ALL_FILES = SOURCE_FILES + REPORT_FILES

DRY_RUN   = ENV.key?("DRY_RUN")
PASS_ONE_ONLY = ENV["PASS"] == "1"
SINGLE_FILE   = ENV["FILE"]

# ── Helpers ───────────────────────────────────────────────────────────────────

def log(msg, level: :info)
  tag = case level
        when :info  then "\e[32m[INFO]\e[0m "
        when :warn  then "\e[33m[WARN]\e[0m "
        when :error then "\e[31m[ERR ]\e[0m "
        when :head  then "\e[36m[====]\e[0m "
        end
  puts "#{tag}#{msg}"
end

def separator = puts("\e[90m#{"─" * 72}\e[0m")

# ── Setup ─────────────────────────────────────────────────────────────────────

SFL::Compiler.configure do |c|
  c.database_url = ENV.fetch("DATABASE_URL", "postgresql:///sfl_compiler_dev")
  c.spacy_model  = ENV.fetch("SPACY_MODEL", "en_core_web_sm")
  c.dspy_provider = ENV.fetch("DSPY_PROVIDER", "openai/gpt-4o-mini")
end

unless DRY_RUN
  log "Connecting to database: #{SFL::Compiler.config.database_url}", level: :head
  db = SFL::Compiler::Database.connect
  SFL::Compiler::Database.setup_extensions(db)
  SFL::Compiler::Migrator.new(db).run_all
  log "Database ready", level: :info

  pipeline = SFL::Compiler::Pipeline.new(db: db)
end

# ── Target files ──────────────────────────────────────────────────────────────

targets = if SINGLE_FILE
  matched = ALL_FILES.select { |f| File.basename(f) == SINGLE_FILE }
  if matched.empty?
    log "FILE=#{SINGLE_FILE} not found in source or report dirs", level: :error
    exit 1
  end
  matched
else
  ALL_FILES
end

targets.select! { |f| File.exist?(f) }

if targets.empty?
  log "No files found. Is NOTEBOOK_SOURCES path correct? #{NOTEBOOK_SOURCES}", level: :error
  exit 1
end

# ── Stats accumulators ────────────────────────────────────────────────────────

total_stats = {
  files: 0,
  sections: 0,
  sections_skipped: 0,
  clauses: 0,
  errors: 0,
  elapsed_ms: 0
}

# ── Main loop ─────────────────────────────────────────────────────────────────

separator
log "Metacognitive Coprocessor — SFL Pipeline Run", level: :head
log "Mode   : #{DRY_RUN ? "DRY RUN" : PASS_ONE_ONLY ? "Pass 1 only" : "Full (Pass 1 + 2)"}"
log "Files  : #{targets.length} (#{SOURCE_FILES.count { |f| targets.include?(f) }} sources, #{REPORT_FILES.count { |f| targets.include?(f) }} reports)"
separator

targets.each do |path|
  file_id   = File.basename(path, ".*")
  file_size = File.size(path)
  separator
  log "#{File.basename(path)}  (#{(file_size / 1024.0).round(1)} KB)", level: :head

  loader = SFL::Compiler::MarkdownLoader.new(path)
  sections = loader.sections

  log "  Sections: #{sections.length}"
  total_stats[:files] += 1

  file_clauses  = 0
  file_skipped  = 0
  file_errors   = 0
  file_start    = Time.now

  sections.each_with_index do |section, idx|
    heading_display = section.heading ? "H#{section.heading_level} \"#{section.heading}\"" : "(preamble)"
    char_count = section.text.length

    if DRY_RUN
      log "  [#{idx + 1}/#{sections.length}] #{section.document_id}"
      log "    #{heading_display} — #{char_count} chars"
      next
    end

    log "  [#{idx + 1}/#{sections.length}] #{heading_display} (#{char_count} chars)"

    t0 = Time.now
    begin
      if PASS_ONE_ONLY
        pairs = pipeline.compile_pass_one(section.text, document_id: section.document_id)
        file_clauses += pairs.length
        pairs.each do |clause, ideational|
          log "    #{ideational.process_type.ljust(12)} #{clause.text.slice(0, 80)}"
        end
      else
        annotated = pipeline.compile(section.text, document_id: section.document_id)
        file_clauses += annotated.length
        annotated.each do |ac|
          log "    [#{ac.ideational.process_type.ljust(12)}] " \
              "mood=#{ac.interpersonal.mood.ljust(13)} " \
              "mod=#{format("%.2f", ac.interpersonal.modality_weight)} " \
              "tenor=#{format("%.2f", ac.interpersonal.tenor)}  " \
              "#{ac.text.slice(0, 60)}…"
        end
      end

      elapsed = ((Time.now - t0) * 1000).round(1)
      log "    ✓ #{pairs&.length || annotated&.length} clauses in #{elapsed}ms"

    rescue SFL::Compiler::PassOneError => e
      file_errors += 1
      log "    PassOneError: #{e.message}", level: :error
    rescue SFL::Compiler::PassTwoError => e
      file_errors += 1
      log "    PassTwoError (section skipped): #{e.message}", level: :warn
    rescue StandardError => e
      file_errors += 1
      log "    Unexpected error: #{e.class} — #{e.message}", level: :error
    end
  end

  file_elapsed = ((Time.now - file_start) * 1000).round(1)
  total_stats[:sections]         += sections.length
  total_stats[:sections_skipped] += file_skipped
  total_stats[:clauses]          += file_clauses
  total_stats[:errors]           += file_errors
  total_stats[:elapsed_ms]       += file_elapsed

  log "  File complete: #{file_clauses} clauses, #{file_errors} errors, #{file_elapsed}ms"
end

# ── Summary ───────────────────────────────────────────────────────────────────

separator
log "Run complete", level: :head
log "  Files processed : #{total_stats[:files]}"
log "  Sections parsed : #{total_stats[:sections]}"
log "  Clauses stored  : #{total_stats[:clauses]}"
log "  Errors          : #{total_stats[:errors]}"
log "  Total time      : #{(total_stats[:elapsed_ms] / 1000.0).round(2)}s"
separator

exit(total_stats[:errors] > 0 ? 1 : 0)
