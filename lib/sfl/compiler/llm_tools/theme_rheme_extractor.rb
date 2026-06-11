# frozen_string_literal: true

require "ruby_llm"

module SFL
  module Compiler
    module LLMTools
      # RubyLLM Tool for extracting Theme/Rheme using SFL theory
      # Delegates to small LLM (Mistral via OpenRouter) what spaCy can't do
      class ThemeRhemeExtractor < RubyLLM::Tool
        desc "Analyze a clause using Systemic Functional Linguistics to identify Theme and Rheme"

        params do
          string :clause_text, description: "The clause to analyze"

          object :spacy_analysis, description: "Syntactic information from spaCy" do
            array :tokens, of: :object, description: "Token information" do
              string :text, description: "Token text"
              string :lemma, description: "Token lemma"
              string :pos, description: "Part of speech tag"
              string :dep, description: "Dependency relation"
              integer :i, description: "Token index"
            end

            object :subject, description: "Subject token if found", required: false do
              string :text
              integer :i
            end

            object :root_verb, description: "Root verb" do
              string :text
              string :pos
            end
          end

          string :mood, description: "Clause mood (declarative, interrogative, imperative)", enum: %w[declarative interrogative imperative]
        end

        # Execute Theme/Rheme analysis using LLM
        def execute(clause_text:, spacy_analysis:, mood:)
          # The LLM prompt explaining SFL Theme/Rheme theory
          prompt = build_sfl_prompt(clause_text, spacy_analysis, mood)

          # Call LLM (Mistral via OpenRouter)
          response = call_llm(prompt)

          # Parse and validate response
          parse_theme_rheme_response(response, clause_text)
        end

        private

        def build_sfl_prompt(clause_text, spacy_analysis, mood)
          tokens_info = spacy_analysis[:tokens].map { |t| "#{t[:text]} (#{t[:pos]}, dep=#{t[:dep]})" }.join(", ")

          <<~PROMPT
            You are an expert in Systemic Functional Linguistics (SFL). Analyze this clause to identify its Theme and Rheme.

            CLAUSE: "#{clause_text}"
            MOOD: #{mood}

            SYNTACTIC STRUCTURE:
            Tokens: #{tokens_info}
            #{spacy_analysis[:subject] ? "Subject: #{spacy_analysis[:subject][:text]}" : "No subject (likely imperative)"}
            Root verb: #{spacy_analysis[:root_verb][:text]}

            SFL THEME DEFINITION:
            - Theme = Starting point / point of departure for the message
            - In DECLARATIVE: Theme is usually the Subject (unmarked) or a fronted element (marked)
            - In INTERROGATIVE: Theme is Finite + Subject (e.g., "Can you")
            - In IMPERATIVE: Theme is the Predicator/verb (no Subject)

            THEME TYPES:
            - Textual Theme: Conjunctions, connectives (e.g., "However", "Therefore")
            - Interpersonal Theme: Modal Adjuncts (e.g., "Surely", "Perhaps")
            - Topical Theme: The main starting point (Subject, fronted element, or Predicator)

            RHEME DEFINITION:
            - Rheme = Everything AFTER the Theme
            - Develops the message, presents new information

            INSTRUCTIONS:
            1. Identify if there's a Textual Theme (conjunction/connective at start)
            2. Identify if there's an Interpersonal Theme (modal adjunct)
            3. Identify the Topical Theme (main starting point)
            4. Everything after Topical Theme is Rheme

            RESPOND IN JSON FORMAT:
            {
              "textual_theme": "word(s) or null",
              "interpersonal_theme": "word(s) or null",
              "topical_theme": "word(s)",
              "full_theme": "all theme components combined",
              "rheme": "remaining part of clause",
              "theme_type": "unmarked/marked/interrogative/imperative",
              "reasoning": "brief explanation of your analysis"
            }

            EXAMPLE 1 - Declarative unmarked:
            Clause: "The implementation leverages architectural principles"
            Response: {
              "textual_theme": null,
              "interpersonal_theme": null,
              "topical_theme": "The implementation",
              "full_theme": "The implementation",
              "rheme": "leverages architectural principles",
              "theme_type": "unmarked",
              "reasoning": "Subject in initial position (typical declarative)"
            }

            EXAMPLE 2 - Textual + Topical:
            Clause: "However, the analysis revealed patterns"
            Response: {
              "textual_theme": "However",
              "interpersonal_theme": null,
              "topical_theme": "the analysis",
              "full_theme": "However, the analysis",
              "rheme": "revealed patterns",
              "theme_type": "unmarked",
              "reasoning": "Conjunction + Subject in typical order"
            }

            EXAMPLE 3 - Interrogative:
            Clause: "Can you explain the reasoning?"
            Response: {
              "textual_theme": null,
              "interpersonal_theme": null,
              "topical_theme": "Can you",
              "full_theme": "Can you",
              "rheme": "explain the reasoning",
              "theme_type": "interrogative",
              "reasoning": "Finite + Subject (interrogative structure)"
            }

            NOW ANALYZE: "#{clause_text}"
          PROMPT
        end

        def call_llm(prompt)
          # Use RubyLLM to call Mistral via OpenRouter
          # Model: openrouter/mistralai/mistral-7b-instruct-v0.2 (cheap, fast)
          chat = RubyLLM::Chat.new(
            model: "openrouter/mistralai/mistral-7b-instruct-v0.2",
            api_key: ENV["OPENROUTER_API_KEY"],
            temperature: 0.1  # Low temperature for consistent analysis
          )

          response = chat.ask(prompt)
          response.content
        rescue StandardError => e
          # Fallback to default if LLM fails
          SFL::Compiler.logger.send_message(
            message: "theme_rheme_llm_failed",
            priority: Journald::LOG_WARNING,
            error: e.message
          )

          # Return default/fallback
          {
            textual_theme: nil,
            interpersonal_theme: nil,
            topical_theme: "unknown",
            full_theme: "unknown",
            rheme: "unknown",
            theme_type: "unmarked",
            reasoning: "LLM call failed - using fallback"
          }.to_json
        end

        def parse_theme_rheme_response(response, clause_text)
          # Parse JSON response from LLM
          require "json"

          result = JSON.parse(response, symbolize_names: true)

          # Validate required fields
          required_fields = [:topical_theme, :full_theme, :rheme, :theme_type]
          missing = required_fields - result.keys

          if missing.any?
            raise "LLM response missing fields: #{missing.join(', ')}"
          end

          result
        rescue JSON::ParserError, StandardError => e
          # If LLM doesn't return valid JSON, fall back to simple heuristic
          SFL::Compiler.logger.send_message(
            message: "theme_rheme_parse_failed",
            priority: Journald::LOG_WARNING,
            error: e.message,
            llm_response: response[0..200]
          )

          # Simple fallback: first word is Theme, rest is Rheme
          words = clause_text.split
          {
            textual_theme: nil,
            interpersonal_theme: nil,
            topical_theme: words.first,
            full_theme: words.first,
            rheme: words[1..-1]&.join(" ") || "",
            theme_type: "unmarked",
            reasoning: "Fallback: parse error"
          }
        end
      end
    end
  end
end
