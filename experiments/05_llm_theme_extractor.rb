#!/usr/bin/env ruby
# frozen_string_literal: true

# Experiment 5: Can LLM extract Theme/Rheme better than spaCy heuristics?
# Usage: ruby experiments/05_llm_theme_extractor.rb

require "bundler/setup"
require "ruby-spacy"
require "ruby_llm"
require "dotenv/load"
require "json"

puts "=" * 60
puts "LLM THEME/RHEME EXPERIMENT: Mistral vs spaCy heuristics"
puts "=" * 60
puts

# Load spaCy
nlp = Spacy::Language.new("en_core_web_sm")

# Same test cases from Experiment 3
test_clauses = [
  {
    text: "The implementation leverages architectural principles",
    expected_theme: "The implementation",
    theme_type: "unmarked topical"
  },
  {
    text: "However, the analysis revealed significant patterns",
    expected_theme: "However, the analysis",
    theme_type: "textual + topical"
  },
  {
    text: "In this context, formality increased dramatically",
    expected_theme: "In this context",
    theme_type: "marked topical"
  },
  {
    text: "Surely, we should reconsider the approach",
    expected_theme: "Surely, we",
    theme_type: "interpersonal + topical"
  },
  {
    text: "Can you explain the reasoning?",
    expected_theme: "Can you",
    theme_type: "interrogative"
  },
  {
    text: "Stop talking and listen",
    expected_theme: "Stop",
    theme_type: "imperative"
  }
]

# Detect mood from spaCy
def detect_mood(doc)
  first_token = doc[0]

  # Imperative: starts with verb base form, no subject
  if first_token.pos == "VERB" && doc.none? { |t| t.dep =~ /nsubj/ }
    return "imperative"
  end

  # Interrogative: starts with auxiliary/modal, or has WH-word
  if first_token.pos =~ /AUX/ || first_token.tag =~ /^W/
    return "interrogative"
  end

  # Default: declarative
  "declarative"
end

# Build spaCy analysis for LLM
def build_spacy_analysis(doc)
  tokens = doc.map do |token|
    {
      text: token.text,
      lemma: token.lemma,
      pos: token.pos,
      dep: token.dep,
      i: token.i
    }
  end

  subject = doc.find { |t| t.dep =~ /nsubj/ }
  root_verb = doc.find { |t| t.dep == "ROOT" } || doc[0]

  {
    tokens: tokens,
    subject: subject ? { text: subject.text, i: subject.i } : nil,
    root_verb: { text: root_verb.text, pos: root_verb.pos }
  }
end

# Configure RubyLLM once
RubyLLM.configure do |config|
  config.openrouter_api_key = ENV["OPENROUTER_API_KEY"]
end

# Call LLM for Theme/Rheme extraction
def extract_with_llm(clause_text, spacy_analysis, mood)
  prompt = <<~PROMPT
    You are an expert in Systemic Functional Linguistics (SFL). Analyze this clause to identify its Theme and Rheme.

    CLAUSE: "#{clause_text}"
    MOOD: #{mood}

    SFL THEME DEFINITION:
    - Theme = Starting point / point of departure
    - In DECLARATIVE: Usually Subject (unmarked) or fronted element (marked)
    - In INTERROGATIVE: Finite + Subject (e.g., "Can you")
    - In IMPERATIVE: The Predicator/verb

    THEME TYPES:
    - Textual: Conjunctions (However, Therefore)
    - Interpersonal: Modal adjuncts (Surely, Perhaps)
    - Topical: Main starting point

    RHEME: Everything after Theme

    RESPOND IN JSON:
    {
      "textual_theme": "word(s) or null",
      "interpersonal_theme": "word(s) or null",
      "topical_theme": "word(s)",
      "full_theme": "all components",
      "rheme": "remaining text",
      "theme_type": "unmarked/marked/interrogative/imperative",
      "reasoning": "explanation"
    }
  PROMPT

  # Use RubyLLM with OpenRouter Mistral
  chat = RubyLLM.chat(model: "openrouter/mistralai/mistral-7b-instruct-v0.2")

  response_text = chat.ask(prompt).content

  # Extract JSON from response (might be wrapped in markdown)
  json_match = response_text.match(/\{.*\}/m)
  if json_match
    JSON.parse(json_match[0], symbolize_names: true)
  else
    raise "No JSON found in LLM response"
  end
rescue => e
  puts "  [ERROR] LLM call failed: #{e.message}"
  {
    full_theme: "ERROR",
    rheme: "ERROR",
    reasoning: "LLM failed: #{e.message}"
  }
end

# Test each clause
results = []
test_clauses.each_with_index do |test_case, idx|
  puts "Test #{idx + 1}: #{test_case[:text]}"
  puts "-" * 60

  # Parse with spaCy
  doc = nlp.read(test_case[:text])
  mood = detect_mood(doc)
  spacy_analysis = build_spacy_analysis(doc)

  # Extract with LLM
  puts "  Calling Mistral LLM..."
  theme_result = extract_with_llm(test_case[:text], spacy_analysis, mood)

  puts "  Expected Theme: '#{test_case[:expected_theme]}'"
  puts "  LLM Theme:      '#{theme_result[:full_theme]}'"
  puts "  LLM Rheme:      '#{theme_result[:rheme]}'"
  puts "  Reasoning:      #{theme_result[:reasoning]}"

  # Check match
  expected_words = test_case[:expected_theme].downcase.split
  extracted_words = theme_result[:full_theme].to_s.downcase.split

  match = (expected_words & extracted_words).size >= (expected_words.size * 0.7) # 70% word overlap

  puts "  Result: #{match ? '✓ MATCH' : '✗ MISMATCH'}"
  puts
  puts "=" * 60
  puts

  results << { test: test_case[:text], match: match, llm_theme: theme_result[:full_theme] }

  # Sleep to avoid rate limiting
  sleep 1
end

# Summary
matches = results.count { |r| r[:match] }
total = results.size
accuracy = (matches.to_f / total * 100).round(1)

puts "EXPERIMENT RESULTS:"
puts "=" * 60
puts

puts "LLM Theme Extraction Accuracy: #{accuracy}%"
puts "  Correct: #{matches} / #{total}"
puts
puts "Compare to Experiment 3 (spaCy heuristics): 16.7%"
puts

improvement = accuracy - 16.7
if accuracy > 80
  puts "✓ EXCELLENT - LLM is FAR BETTER than heuristics!"
  puts "  Improvement: +#{improvement.round(1)}%"
  puts "  Decision: USE LLM for Theme/Rheme extraction"
elsif accuracy > 50
  puts "✓ GOOD - LLM beats heuristics"
  puts "  Improvement: +#{improvement.round(1)}%"
  puts "  Decision: LLM worth the cost for better accuracy"
elsif accuracy > 16.7
  puts "⚠ BETTER - LLM slightly improves over heuristics"
  puts "  Improvement: +#{improvement.round(1)}%"
  puts "  Decision: Marginal gain, evaluate cost vs benefit"
else
  puts "✗ NO IMPROVEMENT - LLM no better than heuristics"
  puts "  Decision: Stick with heuristics or skip Theme/Rheme"
end

puts
puts "✓ Experiment complete. Is LLM worth the cost?"
