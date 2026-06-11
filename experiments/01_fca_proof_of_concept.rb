#!/usr/bin/env ruby
# frozen_string_literal: true

# Experiment 1: Does FCA reveal patterns in conversation data?
# Usage: ruby experiments/01_fca_proof_of_concept.rb sfl_output_mimo/conversation_analysis.json

require "json"

# Simple FCA implementation (no gem dependencies for now - just proof of concept)
class SimpleFCA
  attr_reader :objects, :attributes, :context

  def initialize(objects, attributes, context)
    @objects = objects      # Array of turn IDs
    @attributes = attributes # Array of SFL feature names
    @context = context      # Hash: {turn_id => Set of attribute names}
  end

  def find_concepts
    concepts = []

    # Find maximal object-attribute pairs
    # Concept = (Extent, Intent) where:
    #   Extent = set of objects sharing Intent
    #   Intent = set of attributes shared by Extent

    # Start with individual objects
    objects.each do |obj|
      intent = context[obj]
      extent = objects.select { |o| intent.subset?(context[o]) }

      # Check if this is a maximal concept (not subsumed by another)
      is_maximal = concepts.none? do |c|
        c[:extent].superset?(extent.to_set) && c[:intent].subset?(intent)
      end

      concepts << { extent: extent.to_set, intent: intent } if is_maximal
    end

    # Add top concept (all objects, common attributes)
    common_attrs = context.values.reduce(:&) || Set.new
    concepts << { extent: objects.to_set, intent: common_attrs }

    concepts.uniq
  end

  def find_implications
    implications = []

    attributes.combination(2).each do |attr1, attr2|
      # Check if attr1 implies attr2
      objects_with_attr1 = objects.select { |o| context[o].include?(attr1) }
      objects_with_attr2 = objects.select { |o| context[o].include?(attr2) }

      if objects_with_attr1.to_set.subset?(objects_with_attr2.to_set) && !objects_with_attr1.empty?
        confidence = objects_with_attr1.size.to_f / objects.size
        implications << {
          from: attr1,
          to: attr2,
          confidence: confidence,
          support: objects_with_attr1.size
        }
      end
    end

    implications.sort_by { |i| -i[:confidence] }
  end
end

# Load analysis results
analysis = JSON.parse(File.read(ARGV[0]), symbolize_names: true)

# Build formal context from speaker profiles
puts "=" * 60
puts "FCA EXPERIMENT: Pattern Discovery"
puts "=" * 60
puts

# Extract turns and features
turns = analysis[:tenor_timeline]
objects = turns.map { |t| t[:turn_id] }

# Define SFL attributes from the data
def extract_attributes(turn, analysis)
  attrs = Set.new

  # Find speaker for this turn
  speaker = turn[:speaker]
  profile = analysis[:speaker_profiles][speaker.to_sym]

  # Tenor categories
  tenor = turn[:tenor]
  attrs << "tenor_low" if tenor < 0.4
  attrs << "tenor_mid" if tenor.between?(0.4, 0.6)
  attrs << "tenor_high" if tenor > 0.6

  # Process types (from profile dominant processes)
  if profile
    top_process = profile[:dominant_processes].max_by { |_, count| count }&.first
    attrs << "process_#{top_process}" if top_process

    # Mood distribution
    top_mood = profile[:mood_distribution].max_by { |_, freq| freq }&.first
    attrs << "mood_#{top_mood}" if top_mood
  end

  # Speaker attribute
  attrs << "speaker_#{speaker}"

  attrs
end

# Build context
context = {}
turns.each do |turn|
  context[turn[:turn_id]] = extract_attributes(turn, analysis)
end

# Get unique attributes
all_attributes = context.values.reduce(:|).to_a

puts "Formal Context:"
puts "  Objects (turns): #{objects.size}"
puts "  Attributes (SFL features): #{all_attributes.size}"
puts "  Features: #{all_attributes.join(', ')}"
puts

# Run FCA
fca = SimpleFCA.new(objects, all_attributes, context)
concepts = fca.find_concepts

puts "Concept Lattice Generated:"
puts "  Concepts found: #{concepts.size}"
puts

# Show concepts
concepts.each_with_index do |concept, idx|
  puts "Concept #{idx + 1}:"
  puts "  Extent (turns): #{concept[:extent].to_a.sort.join(', ')}"
  puts "  Intent (features): #{concept[:intent].to_a.join(', ')}"
  puts "  Size: #{concept[:extent].size} turns"
  puts
end

# Find implications
implications = fca.find_implications.first(5) # Top 5

puts "Attribute Implications (Top 5):"
implications.each do |imp|
  puts "  IF #{imp[:from]} THEN #{imp[:to]}"
  puts "    Confidence: #{(imp[:confidence] * 100).round(1)}%"
  puts "    Support: #{imp[:support]} turns"
  puts
end

# Summary statistics
puts "=" * 60
puts "EXPERIMENT RESULTS:"
puts "=" * 60
puts

avg_concept_size = concepts.map { |c| c[:extent].size }.sum / concepts.size.to_f
puts "Average concept size: #{avg_concept_size.round(1)} turns"
puts "Largest concept: #{concepts.max_by { |c| c[:extent].size }[:extent].size} turns"
puts "Most specific concept: #{concepts.min_by { |c| c[:extent].size }[:extent].size} turns"
puts

if implications.any?
  puts "Strongest implication:"
  strongest = implications.first
  puts "  #{strongest[:from]} → #{strongest[:to]}"
  puts "  (#{(strongest[:confidence] * 100).round(1)}% confidence)"
end

puts
puts "✓ Experiment complete. Do the patterns make sense?"
