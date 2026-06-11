#!/usr/bin/env ruby
# frozen_string_literal: true

# Experiment 6: DSPy-based Theme/Rheme extraction
# Usage: ruby experiments/06_dspy_theme_extractor.rb

require "bundler/setup"
require "ruby-spacy"
require "dspy"
require "dotenv/load"

puts "=" * 60
puts "DSPy THEME/RHEME EXPERIMENT: Using proven DSPy.rb"
puts "=" * 60
puts

# Configure DSPy (same as Pass 2)
DSPy.configure do |c|
  c.lm = DSPy::LM.new("openrouter/xiaomi/mimo-v2.5",
    api_key: ENV["OPENROUTER_API_KEY"],
    structured_outputs: true)
end

puts "[INFO] DSPy configured with openrouter/xiaomi/mimo-v2.5"
puts

# Define DSPy Signature for Theme/Rheme analysis
class ThemeRhemeSignature < DSPy::Signature
  description "Analyze a clause using Systemic Functional Linguistics to identify Theme and Rheme. "\
              "Theme is the starting point or point of departure for the message. "\
              "In declarative clauses, Theme is usually the Subject (unmarked) or a fronted element (marked). "\
              "In interrogative clauses, Theme is Finite + Subject (e.g., 'Can you'). "\
              "In imperative clauses, Theme is the Predicator/verb. "\
              "Rheme is everything after the Theme, developing the message with new information."

  input do
    const :clause_text, String, description: "The clause to analyze"
    const :mood, String, description: "Clause mood: declarative, interrogative, or imperative"
    const :tokens, String, description: "Token sequence with POS tags (for context)"
  end

  output do
    const :textual_theme, String, description: "Textual Theme: conjunctions/connectives at start (or 'none')"
    const :interpersonal_theme, String, description: "Interpersonal Theme: modal adjuncts (or 'none')"
    const :topical_theme, String, description: "Topical Theme: main starting point (Subject, fronted element, or Predicator)"
    const :rheme, String, description: "Rheme: everything after the Theme"
    const :theme_type, String, description: "Theme type: unmarked, marked, interrogative, or imperative"
    const :reasoning, String, description: "Brief explanation of the analysis"
  end
end

# Load spaCy
nlp = Spacy::Language.new("en_core_web_sm")

# Test cases
test_clauses = [
  {
    text: "The implementation leverages architectural principles",
    expected_theme: "The implementation",
    mood: "declarative"
  },
  {
    text: "However, the analysis revealed significant patterns",
    expected_theme: "However, the analysis",
    mood: "declarative"
  },
  {
    text: "In this context, formality increased dramatically",
    expected_theme: "In this context",
    mood: "declarative"
  },
  {
    text: "Surely, we should reconsider the approach",
    expected_theme: "Surely, we",
    mood: "declarative"
  },
  {
    text: "Can you explain the reasoning?",
    expected_theme: "Can you",
    mood: "interrogative"
  },
  {
    text: "Stop talking and listen",
    expected_theme: "Stop",
    mood: "imperative"
  }
]

# Create DSPy Chain-of-Thought predictor
theme_analyzer = DSPy::ChainOfThought.new(ThemeRhemeSignature)

# Test each clause
results = []

test_clauses.each_with_index do |test_case, idx|
  puts "Test #{idx + 1}: #{test_case[:text]}"
  puts "-" * 60

  # Parse with spaCy for token info
  doc = nlp.read(test_case[:text])
  tokens_info = doc.map { |t| "#{t.text}(#{t.pos})" }.join(" ")

  # Call DSPy
  puts "  Calling DSPy ChainOfThought..."

  begin
    result = theme_analyzer.call(
      clause_text: test_case[:text],
      mood: test_case[:mood],
      tokens: tokens_info
    )

    full_theme = [
      result.textual_theme != "none" ? result.textual_theme : nil,
      result.interpersonal_theme != "none" ? result.interpersonal_theme : nil,
      result.topical_theme
    ].compact.join(" ")

    puts "  Expected Theme: '#{test_case[:expected_theme]}'"
    puts "  DSPy Theme:     '#{full_theme}'"
    puts "  DSPy Rheme:     '#{result.rheme}'"
    puts "  Type:           #{result.theme_type}"
    puts "  Reasoning:      #{result.reasoning[0..80]}..."

    # Check match (70% word overlap)
    expected_words = test_case[:expected_theme].downcase.split
    extracted_words = full_theme.downcase.split
    overlap = (expected_words & extracted_words).size
    match = overlap >= (expected_words.size * 0.7)

    puts "  Result: #{match ? '✓ MATCH' : '✗ MISMATCH'}"

    results << {
      test: test_case[:text],
      match: match,
      dspy_theme: full_theme,
      reasoning: result.reasoning
    }

  rescue => e
    puts "  [ERROR] DSPy call failed: #{e.message}"
    puts "  #{e.backtrace[0..2].join("\n  ")}"

    results << {
      test: test_case[:text],
      match: false,
      dspy_theme: "ERROR",
      reasoning: e.message
    }
  end

  puts
  puts "=" * 60
  puts

  # Small delay to avoid rate limiting
  sleep 1
end

# Summary
matches = results.count { |r| r[:match] }
total = results.size
accuracy = (matches.to_f / total * 100).round(1)

puts "EXPERIMENT RESULTS:"
puts "=" * 60
puts

puts "DSPy Theme Extraction Accuracy: #{accuracy}%"
puts "  Correct: #{matches} / #{total}"
puts
puts "Compare to:"
puts "  spaCy heuristics (Exp 3): 16.7%"
puts "  RubyLLM (Exp 5): N/A (gem conflict)"
puts

improvement = accuracy - 16.7
if accuracy > 80
  puts "✓ EXCELLENT - DSPy FAR BETTER than heuristics!"
  puts "  Improvement: +#{improvement.round(1)}%"
  puts "  Decision: USE DSPy for Theme/Rheme extraction"
  puts "  Cost: #{total} LLM calls for test, ~673 per conversation"
elsif accuracy > 50
  puts "✓ GOOD - DSPy beats heuristics"
  puts "  Improvement: +#{improvement.round(1)}%"
  puts "  Decision: DSPy worth the cost for better accuracy"
  puts "  Evaluate: Cost vs benefit for production"
elsif accuracy > 16.7
  puts "⚠ BETTER - DSPy improves over heuristics"
  puts "  Improvement: +#{improvement.round(1)}%"
  puts "  Decision: Marginal gain, consider cost"
else
  puts "✗ NO IMPROVEMENT - DSPy no better than heuristics"
  puts "  Decision: Skip Theme/Rheme entirely"
end

puts
puts "✓ Experiment complete. DSPy approach validated?"
