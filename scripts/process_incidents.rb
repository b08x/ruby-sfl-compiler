#!/usr/bin/env ruby
# frozen_string_literal: true

# Example: Process ServiceNow incidents through the SFL pipeline.
#
# Usage:
#   bundle exec ruby scripts/process_incidents.rb
#   PASS=1 bundle exec ruby scripts/process_incidents.rb   # Pass 1 only (no LLM)
#
# This script demonstrates:
#   1. Reading real ServiceNow incident exports
#   2. Running Pass 1 (spaCy) to extract process types, participants
#   3. Running Pass 2 (LLM) to annotate mood, modality, tenor
#   4. Storing clauses + embeddings in PostgreSQL
#   5. Retrieving with SFL scalar filters

require "bundler/setup"
require "dotenv/load"
require "json"
require "pathname"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "sfl/compiler"

# --- Configuration ---

INCIDENTS_DIR = ARGV[0] || File.expand_path("../docs/scrubbed-incidents", __dir__)
PASS1_ONLY = ENV["PASS"] == "1"
DOCUMENT_ID_PREFIX = "incident"

# --- Bootstrap ---

ctx = SFL::Compiler::Bootstrap.call(require_llm: !PASS1_ONLY)

pipeline_args = { db: ctx.db, cache_dir: ".sfl-cache" }
unless PASS1_ONLY
  pipeline_args[:embedder] = SFL::Compiler::Embedder.new(
    model: ctx.config.embedding_model,
    ollama_base_url: ctx.config.ollama_base_url
  )
end

pipeline = SFL::Compiler::Pipeline.new(**pipeline_args)
clause_repo = SFL::Compiler::ClauseRepository.new(ctx.db)

# Pass 1 only: skip Pipeline#compile (which always runs Pass 2) and stub
# the interpersonal/textual payloads, same pattern as ConversationAnalyzer.
def compile_pass_one_only(pipeline, text, document_id)
  pipeline.compile_pass_one(text, document_id:).map.with_index do |(syntactic, ideational), idx|
    clause_id = "#{document_id}-clause-#{idx + 1}"
    SFL::Compiler::Types::AnnotatedClause.new(
      id: clause_id,
      text: syntactic.text,
      syntactic:,
      ideational:,
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id:,
        mood: "declarative", modality_weight: 0.5, tenor: 0.5,
        speaker_attitude: nil,
        reasoning: "Pass 2 skipped — placeholder values",
        annotation_source: "stub"
      ),
      document_id:,
      compiled_at: Time.now
    )
  end
end

# --- Read incidents ---

incidents = []
incidents_dir = Pathname.new(INCIDENTS_DIR)
incidents_dir.children.select { |f| f.extname == ".txt" }.sort.each do |path|
  text = path.read.strip
  next if text.empty?

  # Extract short description (first meaningful line after headers)
  short_desc = text.lines.find do |l|
    l.strip.length > 10 && !l.strip.start_with?("Incident", "Page", "Report", "Run ", "Table", "Contact", "Manual",
      "Urgency", "Impact", "Priority", "Assignment", "Assigned", "Workstation", "Configuration", "Category", "Subcategory", "Please", "LogMeIn", "Short ", "Description:", "Time ", "Parent", "Notes", "Watch", "Work notes", "Additional")
  end&.strip

  incidents << {
    id: path.basename(".txt").to_s,
    text:,
    short_desc: short_desc || text.lines.first(5).map(&:strip).reject(&:empty?).first,
  }
end

puts "=" * 70
puts "SFL Pipeline — ServiceNow Incident Processing"
puts "=" * 70
puts "Incidents: #{incidents.size}"
puts "Mode: #{PASS1_ONLY ? 'Pass 1 only (spaCy)' : 'Full pipeline (spaCy + LLM)'}"
puts "Database: #{ctx.config.database_url}"
puts

# --- Process each incident ---

results = []

incidents.each do |inc|
  doc_id = "#{DOCUMENT_ID_PREFIX}-#{inc[:id]}"
  puts "--- #{inc[:id]} ---"
  puts "  Short: #{inc[:short_desc][0..80]}..."

  begin
    annotated = if PASS1_ONLY
      compile_pass_one_only(pipeline, inc[:text], doc_id)
    else
      clause_repo.delete_by_document(doc_id)
      pipeline.compile(inc[:text], document_id: doc_id, resume: true)
    end

    # Summarize results
    process_types = annotated.map { |a| a.ideational&.process_type }.compact
    moods = annotated.map { |a| a.interpersonal&.mood }.compact
    modalities = annotated.map { |a| a.interpersonal&.modality_weight }.compact
    sources = annotated.map { |a| a.interpersonal&.annotation_source }.compact

    process_dist = process_types.tally.sort_by { |_, v| -v }
    mood_dist = moods.tally.sort_by { |_, v| -v }
    avg_modality = modalities.empty? ? 0.0 : (modalities.sum / modalities.size).round(3)
    source_dist = sources.tally

    puts "  Clauses: #{annotated.size}"
    puts "  Process types: #{process_dist.map { |k, v| "#{k}(#{v})" }.join(', ')}"
    puts "  Moods: #{mood_dist.map { |k, v| "#{k}(#{v})" }.join(', ')}"
    puts "  Avg modality: #{avg_modality}"
    puts "  Sources: #{source_dist.map { |k, v| "#{k}:#{v}" }.join(', ')}"

    results << {
      id: inc[:id],
      short_desc: inc[:short_desc],
      clause_count: annotated.size,
      process_types: process_dist.to_h,
      moods: mood_dist.to_h,
      avg_modality:,
      sources: source_dist,
    }
  rescue => e
    puts "  ERROR: #{e.class}: #{e.message}"
    results << { id: inc[:id], error: e.message }
  end

  puts
end

# --- Summary ---

puts "=" * 70
puts "SUMMARY"
puts "=" * 70

total_clauses = results.sum { |r| r[:clause_count] || 0 }
all_processes = results.flat_map do |r|
  r[:process_types].to_a
end.group_by(&:first).transform_values { |v| v.sum(&:last) }
all_moods = results.flat_map { |r| r[:moods].to_a }.group_by(&:first).transform_values { |v| v.sum(&:last) }
all_sources = results.flat_map { |r| r[:sources].to_a }.group_by(&:first).transform_values { |v| v.sum(&:last) }

puts "Total incidents: #{results.size}"
puts "Total clauses: #{total_clauses}"
puts "Process type distribution: #{all_processes.sort_by { |_, v| -v }.map { |k, v| "#{k}:#{v}" }.join(', ')}"
puts "Mood distribution: #{all_moods.sort_by { |_, v| -v }.map { |k, v| "#{k}:#{v}" }.join(', ')}"
puts "Annotation sources: #{all_sources.sort_by { |_, v| -v }.map { |k, v| "#{k}:#{v}" }.join(', ')}"
puts

# --- Retrieval demo ---

unless PASS1_ONLY
  puts "=" * 70
  puts "RETRIEVAL DEMO"
  puts "=" * 70

  embedder = SFL::Compiler::Embedder.new(
    model: ctx.config.embedding_model,
    ollama_base_url: ctx.config.ollama_base_url
  )
  retriever = SFL::Compiler::HybridRetriever.new(db: ctx.db, embedder:)

  queries = [
    { query: "system down", filters: { process_type: "material" } },
    { query: "account unlock", filters: { mood: "imperative" } },
    { query: "monitor issue", filters: { min_modality: 0.7 } },
  ]

  queries.each do |q|
    puts "\nQuery: #{q[:query]}"
    puts "Filters: #{q[:filters]}"
    results = retriever.retrieve(q[:query], limit: 3, filters: q[:filters])
    if results.empty?
      puts "  No results (store incidents first with --store)"
    else
      results.each_with_index do |r, i|
        puts "  #{i + 1}. [#{r[:document_id]}] #{r[:text][0..60]}..."
      end
    end
  end
end

puts "\nDone."
