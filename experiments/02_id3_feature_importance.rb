#!/usr/bin/env ruby
# frozen_string_literal: true

# Experiment 2: Which SFL features best predict speaker?
# Usage: ruby experiments/02_id3_feature_importance.rb sfl_output_mimo/conversation_analysis.json

require "json"
require "decisiontree"

# Load analysis
analysis = JSON.parse(File.read(ARGV[0]), symbolize_names: true)

puts "=" * 60
puts "ID3 EXPERIMENT: Feature Importance for Speaker Classification"
puts "=" * 60
puts

# Extract features per turn
def extract_features(turn, speaker_profiles)
  speaker = turn[:speaker]
  profile = speaker_profiles[speaker.to_sym]

  # Discretize continuous values for ID3
  tenor_cat = if turn[:tenor] < 0.4
                "low"
              elsif turn[:tenor] < 0.6
                "mid"
              else
                "high"
              end

  # Get dominant process type for this speaker
  process = profile[:dominant_processes].max_by { |_, count| count }&.first || "unknown"

  # Get dominant mood
  mood = profile[:mood_distribution].max_by { |_, freq| freq }&.first || "declarative"

  # Modality (from turn's timeline - we don't have per-turn modality, use speaker avg)
  modality_cat = if profile[:avg_modality] < 0.4
                   "low"
                 elsif profile[:avg_modality] < 0.6
                   "mid"
                 else
                   "high"
                 end

  [tenor_cat, process.to_s, mood.to_s, modality_cat]
end

# Build training data
turns = analysis[:tenor_timeline]
speaker_profiles = analysis[:speaker_profiles]

# Attribute names
attributes = ["tenor", "process_type", "mood", "modality"]

# Training instances: [tenor, process, mood, modality, speaker_class]
training_data = turns.map do |turn|
  features = extract_features(turn, speaker_profiles)
  speaker_class = turn[:speaker]
  features + [speaker_class]
end

puts "Training Data:"
puts "  Instances: #{training_data.size}"
puts "  Features: #{attributes.join(', ')}"
puts "  Classes: #{training_data.map(&:last).uniq.join(', ')}"
puts

# Build decision tree
dec_tree = DecisionTree::ID3Tree.new(attributes, training_data, "Robert", :discrete)
dec_tree.train

puts "Decision Tree Built!"
puts "  (skipping graphviz visualization - needs graphr gem)"
puts

# Test accuracy (simple: predict on training data)
correct = 0
training_data.each do |instance|
  features = instance[0..-2]
  actual_class = instance.last
  predicted_class = dec_tree.predict(features)

  correct += 1 if predicted_class == actual_class
end

accuracy = (correct.to_f / training_data.size * 100).round(1)
puts "Training Accuracy: #{accuracy}%"
puts "  (#{correct} / #{training_data.size} correct)"
puts

# Feature importance via ablation test
puts "Feature Importance via Ablation Test:"
puts "  (Remove each feature, see how much accuracy drops)"
puts

feature_importance = {}

attributes.each do |feature_to_remove|
  # Train without this feature
  reduced_attrs = attributes - [feature_to_remove]
  reduced_data = training_data.map do |instance|
    idx_to_remove = attributes.index(feature_to_remove)
    instance.dup.tap { |i| i.delete_at(idx_to_remove) }
  end

  tree = DecisionTree::ID3Tree.new(reduced_attrs, reduced_data, "Robert", :discrete)
  tree.train

  # Test accuracy
  correct_ablated = 0
  reduced_data.each do |instance|
    features = instance[0..-2]
    actual = instance.last
    predicted = tree.predict(features)
    correct_ablated += 1 if predicted == actual
  end

  ablated_accuracy = (correct_ablated.to_f / reduced_data.size * 100).round(1)
  accuracy_drop = accuracy - ablated_accuracy

  feature_importance[feature_to_remove] = accuracy_drop
end

# Rank by importance (larger drop = more important)
ranked_features = feature_importance.sort_by { |_, drop| -drop }

ranked_features.each_with_index do |(feature, drop), idx|
  puts "  #{idx + 1}. #{feature}: #{drop.round(1)}% importance"
  puts "     (removing it drops accuracy by #{drop.round(1)}%)"
  puts
end

# Show decision rules
puts "=" * 60
puts "EXPERIMENT RESULTS:"
puts "=" * 60
puts

if ranked_features.any?
  most_important = ranked_features.first[0]
  puts "MOST IMPORTANT FEATURE: #{most_important}"
  puts "  → This is THE key differentiator between speakers"
  puts

  least_important = ranked_features.last[0]
  puts "LEAST IMPORTANT: #{least_important}"
  puts "  → Doesn't help distinguish speakers much"
  puts
end

puts "Accuracy: #{accuracy}%"
if accuracy > 80
  puts "  ✓ EXCELLENT - ID3 can classify speakers well!"
elsif accuracy > 60
  puts "  ✓ GOOD - Reasonable classification power"
else
  puts "  ✗ POOR - Features don't distinguish speakers well"
end

puts
puts "✓ Experiment complete. Are the important features surprising?"
