#!/usr/bin/env ruby
# frozen_string_literal: true

# One-section worker for rolling_synthesis_validation.rb, run as its own
# OS process (via `timeout N bundle exec ruby ...` in a driver loop) so a
# single hung LLM call can be killed from outside without losing progress
# on the rest of the document — DSPy/OpenRouter calls were observed to
# hang past every configured timeout layer (chunk_timeout, batch_attempts)
# during this validation; see RESULTS.md.
#
# Usage: bundle exec ruby experiments/process_one_pdf_section.rb <section_index>

require "sfl-compiler"

section_index = ARGV.fetch(0).to_i
PDF_PATH = File.expand_path(
  "~/Notebook/assets/pdf/Chomsky’s Universal Grammar and Halliday’s Systemic Functional Linguistics.pdf"
)

ctx = SFL::Compiler::Bootstrap.call(require_db: true, require_llm: true, load_dotenv: true)

sections = SFL::Compiler::PdfLoader.load(PDF_PATH)
section = sections.fetch(section_index)

pass_one = SFL::Compiler::PassOneEngine.new
extractor = SFL::Compiler::IdeationalExtractor.new
pass_two = SFL::Compiler::PassTwoEngine.new
clause_repo = SFL::Compiler::ClauseRepository.new(ctx.db)

syntactic = pass_one.process(section.text, document_id: section.document_id)
pairs = syntactic.map { |c| [c, extractor.extract(c)] }
annotated = pass_two.annotate_batch(pairs, concurrency: 1)
annotated.each { |a| clause_repo.store(a, source_type: "vault_pdf") }

puts "section #{section_index}: stored #{annotated.size} clauses"
