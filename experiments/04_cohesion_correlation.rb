#!/usr/bin/env ruby
# frozen_string_literal: true

# Experiment 4: Does cohesion correlate with tenor/modality?
# Usage: ruby experiments/04_cohesion_correlation.rb sfl_output_mimo/conversation_analysis.json

require "json"
require "ruby-spacy"

puts "=" * 60
puts "COHESION EXPERIMENT: Does text flow correlate with formality?"
puts "=" * 60
puts

# Load spaCy
nlp = Spacy::Language.new("en_core_web_sm")

# Load analysis results
analysis_path = ARGV[0] || "sfl_output_mimo/conversation_analysis.json"
unless File.exist?(analysis_path)
  puts "ERROR: Analysis file not found: #{analysis_path}"
  exit 1
end

# We need the actual turn text, not just the analysis
# Load the original conversation
conversation_path = "/home/b08x/Workspace/Datasets/steve-oliver-2025-08-29@13h25m38s.jsonl"
unless File.exist?(conversation_path)
  puts "ERROR: Conversation file not found"
  puts "  Looking for: #{conversation_path}"
  exit 1
end

puts "Loading conversation and analysis..."
puts

# Load turns with text
turns_data = File.readlines(conversation_path).map { |line| JSON.parse(line, symbolize_names: true) }
analysis = JSON.parse(File.read(analysis_path), symbolize_names: true)

# Calculate cohesion metrics
def calculate_cohesion(text, nlp)
  doc = nlp.read(text)
  tokens = doc.to_a
  return { repetition: 0.0, conjunction_density: 0.0, pronoun_density: 0.0 } if tokens.empty?

  # 1. Lexical Repetition
  lemmas = tokens.map(&:lemma).map(&:downcase)
  content_lemmas = tokens.select { |t| t.pos =~ /NOUN|VERB|ADJ|ADV/ }.map(&:lemma).map(&:downcase)

  repetition_score = if content_lemmas.size > 1
                       unique_content = content_lemmas.uniq.size
                       1.0 - (unique_content.to_f / content_lemmas.size)
                     else
                       0.0
                     end

  # 2. Conjunction Density (cohesive links)
  conjunctions = tokens.count { |t| t.pos =~ /CCONJ|SCONJ/ }
  conjunction_density = conjunctions.to_f / tokens.size

  # 3. Pronoun Density (reference)
  pronouns = tokens.count { |t| t.pos == "PRON" }
  pronoun_density = pronouns.to_f / tokens.size

  {
    repetition: repetition_score,
    conjunction_density: conjunction_density,
    pronoun_density: pronoun_density
  }
end

# Analyze each turn
results = []

analysis[:tenor_timeline].each do |turn_info|
  turn_id = turn_info[:turn_id]
  tenor = turn_info[:tenor]
  speaker = turn_info[:speaker]

  # Find matching turn in original data
  turn_data = turns_data[turn_id - 1] # 1-indexed in timeline
  next unless turn_data

  text = turn_data[:mes]

  # Get speaker's modality from profile
  profile = analysis[:speaker_profiles][speaker.to_sym]
  modality = profile ? profile[:avg_modality] : 0.5

  # Calculate cohesion
  cohesion = calculate_cohesion(text, nlp)

  results << {
    turn_id: turn_id,
    speaker: speaker,
    tenor: tenor,
    modality: modality,
    **cohesion,
    word_count: text.split.size
  }

  # Show progress
  print "." if turn_id % 5 == 0
end

puts
puts "Analyzed #{results.size} turns"
puts

# Calculate correlations
def correlation(x_values, y_values)
  n = x_values.size
  return 0.0 if n < 2

  mean_x = x_values.sum / n.to_f
  mean_y = y_values.sum / n.to_f

  numerator = x_values.zip(y_values).map { |x, y| (x - mean_x) * (y - mean_y) }.sum
  denominator_x = Math.sqrt(x_values.map { |x| (x - mean_x)**2 }.sum)
  denominator_y = Math.sqrt(y_values.map { |y| (y - mean_y)**2 }.sum)

  return 0.0 if denominator_x == 0 || denominator_y == 0

  numerator / (denominator_x * denominator_y)
end

# Extract value arrays
tenors = results.map { |r| r[:tenor] }
modalities = results.map { |r| r[:modality] }
repetitions = results.map { |r| r[:repetition] }
conjunctions = results.map { |r| r[:conjunction_density] }
pronouns = results.map { |r| r[:pronoun_density] }

puts "=" * 60
puts "COHESION METRICS:"
puts "=" * 60
puts

puts "Repetition (lexical cohesion):"
puts "  Mean: #{(repetitions.sum / repetitions.size).round(3)}"
puts "  Range: #{repetitions.min.round(3)} - #{repetitions.max.round(3)}"
puts

puts "Conjunction Density:"
puts "  Mean: #{(conjunctions.sum / conjunctions.size).round(3)}"
puts "  Range: #{conjunctions.min.round(3)} - #{conjunctions.max.round(3)}"
puts

puts "Pronoun Density (reference):"
puts "  Mean: #{(pronouns.sum / pronouns.size).round(3)}"
puts "  Range: #{pronouns.min.round(3)} - #{pronouns.max.round(3)}"
puts

puts "=" * 60
puts "CORRELATIONS:"
puts "=" * 60
puts

# Correlations with Tenor
rep_tenor_corr = correlation(repetitions, tenors)
conj_tenor_corr = correlation(conjunctions, tenors)
pron_tenor_corr = correlation(pronouns, tenors)

puts "Cohesion ↔ Tenor (formality):"
puts "  Repetition ↔ Tenor: #{rep_tenor_corr.round(3)}"
puts "    #{rep_tenor_corr > 0 ? 'Positive' : 'Negative'}: More repetition = #{rep_tenor_corr > 0 ? 'more' : 'less'} formal"
puts
puts "  Conjunction ↔ Tenor: #{conj_tenor_corr.round(3)}"
puts "    #{conj_tenor_corr > 0 ? 'Positive' : 'Negative'}: More conjunctions = #{conj_tenor_corr > 0 ? 'more' : 'less'} formal"
puts
puts "  Pronouns ↔ Tenor: #{pron_tenor_corr.round(3)}"
puts "    #{pron_tenor_corr > 0 ? 'Positive' : 'Negative'}: More pronouns = #{pron_tenor_corr > 0 ? 'more' : 'less'} formal"
puts

# Correlations with Modality
rep_mod_corr = correlation(repetitions, modalities)
conj_mod_corr = correlation(conjunctions, modalities)
pron_mod_corr = correlation(pronouns, modalities)

puts "Cohesion ↔ Modality (certainty):"
puts "  Repetition ↔ Modality: #{rep_mod_corr.round(3)}"
puts "    #{rep_mod_corr > 0 ? 'Positive' : 'Negative'}: More repetition = #{rep_mod_corr > 0 ? 'more' : 'less'} certain"
puts
puts "  Conjunction ↔ Modality: #{conj_mod_corr.round(3)}"
puts "    #{conj_mod_corr > 0 ? 'Positive' : 'Negative'}: More conjunctions = #{conj_mod_corr > 0 ? 'more' : 'less'} certain"
puts
puts "  Pronouns ↔ Modality: #{pron_mod_corr.round(3)}"
puts "    #{pron_mod_corr > 0 ? 'Positive' : 'Negative'}: More pronouns = #{pron_mod_corr > 0 ? 'more' : 'less'} certain"
puts

puts "=" * 60
puts "EXPERIMENT RESULTS:"
puts "=" * 60
puts

# Find strongest correlations
all_corrs = [
  { metric: "Repetition ↔ Tenor", value: rep_tenor_corr.abs },
  { metric: "Conjunction ↔ Tenor", value: conj_tenor_corr.abs },
  { metric: "Pronouns ↔ Tenor", value: pron_tenor_corr.abs },
  { metric: "Repetition ↔ Modality", value: rep_mod_corr.abs },
  { metric: "Conjunction ↔ Modality", value: conj_mod_corr.abs },
  { metric: "Pronouns ↔ Modality", value: pron_mod_corr.abs }
].sort_by { |c| -c[:value] }

puts "Strongest Correlations:"
all_corrs.first(3).each_with_index do |corr, idx|
  puts "  #{idx + 1}. #{corr[:metric]}: #{corr[:value].round(3)}"
end
puts

if all_corrs.first[:value] > 0.3
  puts "✓ MEANINGFUL CORRELATION FOUND"
  puts "  Decision: Cohesion metrics ARE worth tracking"
  puts "  Top finding: #{all_corrs.first[:metric]}"
elsif all_corrs.first[:value] > 0.15
  puts "⚠ WEAK CORRELATION"
  puts "  Decision: Cohesion might matter, needs more data"
else
  puts "✗ NO MEANINGFUL CORRELATION"
  puts "  Decision: Skip cohesion metrics for now"
end

puts
puts "✓ Experiment complete. Does cohesion matter?"
