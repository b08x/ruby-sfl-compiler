#!/usr/bin/env ruby
# frozen_string_literal: true

# Experiment 3: Can we extract Theme/Rheme using spaCy?
# Usage: ruby experiments/03_theme_rheme_extractor.rb

require "bundler/setup"
require "ruby-spacy"

puts "=" * 60
puts "THEME/RHEME EXPERIMENT: Can spaCy identify Theme?"
puts "=" * 60
puts

# Load spaCy model
nlp = Spacy::Language.new("en_core_web_sm")

# Test cases with known Theme/Rheme structure
test_clauses = [
  {
    text: "The implementation leverages architectural principles",
    expected_theme: "The implementation",
    theme_type: "unmarked topical (Subject in declarative)",
    notes: "Typical declarative - Subject is Theme"
  },
  {
    text: "However, the analysis revealed significant patterns",
    expected_theme: "However, the analysis",
    theme_type: "textual + topical (conjunction + Subject)",
    notes: "Textual Theme (However) + Topical Theme (the analysis)"
  },
  {
    text: "In this context, formality increased dramatically",
    expected_theme: "In this context",
    theme_type: "marked topical (fronted Adjunct)",
    notes: "Marked Theme - prepositional phrase fronted"
  },
  {
    text: "Surely, we should reconsider the approach",
    expected_theme: "Surely, we",
    theme_type: "interpersonal + topical (modal + Subject)",
    notes: "Interpersonal Theme (Surely) + Topical (we)"
  },
  {
    text: "Can you explain the reasoning?",
    expected_theme: "Can you",
    theme_type: "interrogative (Finite + Subject)",
    notes: "Interrogative mood - Finite^Subject order"
  },
  {
    text: "Stop talking and listen",
    expected_theme: "Stop",
    theme_type: "imperative (Verb only)",
    notes: "Imperative mood - no Subject, Verb is Theme"
  }
]

# Theme extraction logic
def extract_theme(doc)
  return nil if doc.length == 0

  # For declarative: Theme is typically the Subject
  # For interrogative: Theme is Finite + Subject
  # For imperative: Theme is the Verb

  first_token = doc[0]

  # Check for textual Theme (conjunctions, connectives)
  textual_theme = []
  idx = 0
  while idx < doc.length && (doc[idx].pos == "CCONJ" || doc[idx].pos == "SCONJ" ||
                              doc[idx].dep == "advmod" && doc[idx].text.downcase =~ /however|therefore|thus|hence/)
    textual_theme << doc[idx].text
    idx += 1
  end

  # Check for interpersonal Theme (modal Adjuncts)
  interpersonal_theme = []
  while idx < doc.length && (doc[idx].dep == "advmod" && doc[idx].text.downcase =~ /surely|perhaps|probably|maybe/)
    interpersonal_theme << doc[idx].text
    idx += 1
  end

  # Find topical Theme
  topical_theme = []

  # Look for Subject (nsubj, nsubjpass)
  subject = doc.select { |token| token.dep =~ /nsubj/ }.first

  if subject
    # Collect Subject and its dependents (determiners, adjectives, etc.)
    # that come before it or are its children
    subject_span_start = subject.i
    subject_span_end = subject.i

    # Include left dependents (determiners, adjectives)
    doc.each do |token|
      if token.head == subject && token.i < subject.i
        subject_span_start = [subject_span_start, token.i].min
      end
    end

    # Include right dependents that are part of the nominal group
    doc.each do |token|
      if token.head == subject && token.i > subject.i &&
         (token.dep =~ /compound|amod|nummod|prep/ || token.pos == "DET")
        subject_span_end = [subject_span_end, token.i].max
      end
    end

    topical_theme = doc[subject_span_start..subject_span_end].map(&:text)
  else
    # No subject found - might be imperative or marked theme
    # For marked theme (fronted Adjunct), take first phrase
    if first_token.dep =~ /advmod|prep|npadvmod/
      # Find the extent of the fronted element
      topical_theme = [first_token.text]
      first_token.subtree.each do |token|
        topical_theme << token.text if token.i > first_token.i
      end
    else
      # Fallback: just take first token (imperative case)
      topical_theme = [first_token.text]
    end
  end

  # Combine all Theme components
  theme_parts = (textual_theme + interpersonal_theme + topical_theme).compact

  {
    full_theme: theme_parts.join(" "),
    textual: textual_theme.empty? ? nil : textual_theme.join(" "),
    interpersonal: interpersonal_theme.empty? ? nil : interpersonal_theme.join(" "),
    topical: topical_theme.join(" "),
    rheme: doc[(idx + topical_theme.size)..-1]&.map(&:text)&.join(" ")
  }
end

# Test each clause
results = []
test_clauses.each_with_index do |test_case, idx|
  puts "Test #{idx + 1}: #{test_case[:text]}"
  puts "-" * 60

  doc = nlp.read(test_case[:text])
  theme = extract_theme(doc)

  puts "Expected Theme: '#{test_case[:expected_theme]}'"
  puts "Extracted Theme: '#{theme[:full_theme]}'"
  puts
  puts "Theme Components:"
  puts "  Textual: #{theme[:textual] || '(none)'}"
  puts "  Interpersonal: #{theme[:interpersonal] || '(none)'}"
  puts "  Topical: '#{theme[:topical]}'"
  puts "  Rheme: '#{theme[:rheme]}'"
  puts
  puts "Type: #{test_case[:theme_type]}"
  puts "Notes: #{test_case[:notes]}"

  # Check if extraction matches expectation
  match = theme[:full_theme].include?(test_case[:expected_theme].split.first)
  puts
  puts match ? "✓ MATCH" : "✗ MISMATCH"
  puts
  puts "=" * 60
  puts

  results << { test: test_case[:text], match: match, theme: theme[:full_theme] }
end

# Summary
puts "EXPERIMENT RESULTS:"
puts "=" * 60
puts

matches = results.count { |r| r[:match] }
total = results.size
accuracy = (matches.to_f / total * 100).round(1)

puts "Theme Extraction Accuracy: #{accuracy}%"
puts "  Correct: #{matches} / #{total}"
puts

if accuracy > 70
  puts "✓ SUCCESS - spaCy can reliably identify Theme"
  puts "  Decision: BUILD the Theme/Rheme extractor"
elsif accuracy > 50
  puts "⚠ PARTIAL - Theme extraction works but needs refinement"
  puts "  Decision: Build with caution, expect edge cases"
else
  puts "✗ FAILURE - spaCy cannot reliably extract Theme"
  puts "  Decision: Need different approach (rule-based? manual annotation?)"
end

puts
puts "Next step: Test on real conversation clauses"
