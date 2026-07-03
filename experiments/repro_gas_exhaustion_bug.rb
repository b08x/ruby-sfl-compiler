#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal repro: CognitiveGas's on_gas_exhausted callback is documented as
# firing "with the IDs of the clauses in the current chunk" so a caller
# can compress "the clauses processed so far" (pass_two_engine.rb,
# #trigger_rolling_synthesis). In practice it fires with Pass-1
# SyntacticClause ids for a chunk that hasn't been Pass-2-annotated OR
# stored yet — IntermediateGenieJob looks clauses up by
# AnnotatedClause#id (a *different*, freshly-generated UUID) in the
# `clauses` table, so the lookup always returns nil and the resulting
# Axiomatic summary is built from zero real clauses.
#
# Usage: bundle exec ruby experiments/repro_gas_exhaustion_bug.rb

require "sfl-compiler"

SFL::Compiler::Bootstrap.call(require_db: true, require_llm: true, load_dotenv: true)

text = "The system failed under load. Engineers investigated the root cause. " \
       "They found a memory leak in the connection pool."
pass_one = SFL::Compiler::PassOneEngine.new
extractor = SFL::Compiler::IdeationalExtractor.new
syntactic = pass_one.process(text, document_id: "repro-doc")
pairs = syntactic.map { |c| [c, extractor.extract(c)] }
puts "Pass-1 SyntacticClause ids: #{syntactic.map(&:id)}"

captured_job = nil
gas = SFL::Compiler::CognitiveGas.new(budget: 0) # exhausted immediately
pass_two = SFL::Compiler::PassTwoEngine.new(
  circuit_breaker: gas,
  on_gas_exhausted: lambda { |clause_ids|
    puts "on_gas_exhausted fired with ids: #{clause_ids}"
    job = SFL::Compiler::IntermediateGenieJob.new(params: { clause_ids: clause_ids, workflow_id: "repro" })
    job.perform
    captured_job = job
  }
)

annotated = pass_two.annotate_batch(pairs)
puts "AnnotatedClause ids (what actually lands in `clauses.external_id`): #{annotated.map(&:id)}"
puts "IDs match: #{syntactic.map(&:id).sort == annotated.map(&:id).sort}"
puts "IntermediateGenieJob output: #{captured_job&.output_payload}"
