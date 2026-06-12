#!/usr/bin/env ruby
# frozen_string_literal: true

# Conversation Analysis Template Script
#
# Loads JSONL conversation data, runs SFL compilation on each turn,
# and generates multi-format analysis outputs (CSV, JSON, Markdown).
#
# Usage:
#   ruby conversation_analysis_template.rb <input.jsonl> <output_dir>
#
# Environment:
#   PASS=1   Skip Pass 2 (LLM annotation) — syntactic/ideational only, faster

require "bundler/setup"
require "dotenv/load"
require "json"
require "time"
require "journald/logger"
require "dspy"
require_relative "../../../lib/sfl-compiler"

PASS_ONE_ONLY = ENV["PASS"] == "1"

SFL::Compiler.configure do |c|
  c.database_url = ENV.fetch("DATABASE_URL", "postgresql:///sfl_compiler_dev")
  c.spacy_model  = ENV.fetch("SPACY_MODEL", "en_core_web_sm")
  c.dspy_provider = ENV.fetch("DSPY_PROVIDER", "openai/gpt-4o-mini")
end

unless PASS_ONE_ONLY
  provider = ENV.fetch("DSPY_PROVIDER", "openai/gpt-4o-mini")
  api_key = if provider.start_with?("openrouter/")
    ENV.fetch("OPENROUTER_API_KEY", nil)
  elsif provider.start_with?("google/")
    ENV.fetch("GOOGLE_API_KEY", nil)
  elsif provider.start_with?("openai/")
    ENV.fetch("OPENAI_API_KEY", nil)
  elsif provider.start_with?("anthropic/")
    ENV.fetch("ANTHROPIC_API_KEY", nil)
  else
    ENV.fetch("OPENROUTER_API_KEY", nil)
  end

  if api_key && !api_key.empty?
    puts "[INFO] Configuring DSPy..."
    puts "[INFO] Provider: #{provider}"
    puts "[INFO] API key: #{api_key[0..15]}..."

    begin
      DSPy.configure do |c|
        c.lm = DSPy::LM.new(provider,
          api_key: api_key,
          structured_outputs: true)
      end
      puts "[SUCCESS] DSPy configured - Pass 2 will use LLM for tenor/modality annotation"
    rescue => e
      puts "[ERROR] Failed to configure DSPy: #{e.class}: #{e.message}"
      puts "[WARN] Pass 2 will use circuit breaker defaults (all tenor=0.5, modality=0.5)"
    end
  else
    puts "[WARN] No API key found for #{provider}"
    puts "[WARN] Pass 2 will use circuit breaker defaults (all tenor=0.5, modality=0.5)"
  end
end

module SFL
  module Compiler
    class ConversationAnalyzer
      attr_reader :db, :pipeline, :logger

      def initialize(database_url: nil)
        @database_url = database_url || ENV.fetch("DATABASE_URL", "postgresql:///sfl_compiler_dev")
        @logger = Journald::Logger.new("conversation-analyzer")
        @db = setup_database
        @pipeline = SFL::Compiler::Pipeline.new(db: @db)
      end

      def load_jsonl(jsonl_path)
        turns = []
        File.readlines(jsonl_path).each_with_index do |line, idx|
          begin
            turns << JSON.parse(line.strip, symbolize_names: true)
          rescue JSON::ParserError => e
            @logger.send_message(
              message: "jsonl_parse_error",
              priority: Journald::LOG_WARNING,
              line_number: idx + 1,
              error: e.message
            )
          end
        end
        turns
      end

      def compile_turn(turn_data, turn_id)
        message_text = turn_data[:mes]
        speaker = turn_data[:name]
        timestamp = parse_timestamp(turn_data[:send_date])

        if PASS_ONE_ONLY
          # Pass 1 only: syntactic + ideational, skip LLM annotation
          pass1_results = @pipeline.compile_pass_one(
            message_text,
            document_id: "turn-#{turn_id}"
          )

          clauses = pass1_results.map.with_index do |(syntactic, ideational), idx|
            now = Time.now
            Types::AnnotatedClause.new(
              id: "turn-#{turn_id}-clause-#{idx + 1}",
              text: syntactic.text,
              syntactic: syntactic,
              ideational: ideational,
              interpersonal: Types::InterpersonalPayload.new(
                clause_id: "turn-#{turn_id}-clause-#{idx + 1}",
                mood: "declarative",
                modality_weight: 0.5,
                tenor: 0.5,
                speaker_attitude: nil,
                reasoning: "Pass 2 skipped (PASS=1) — placeholder values",
                annotation_source: "stub"
              ),
              document_id: "turn-#{turn_id}",
              compiled_at: now
            )
          end
        else
          clauses = @pipeline.compile(
            message_text,
            document_id: "turn-#{turn_id}",
            store: false,
            embed: false
          )
        end

        avg_tenor = clauses.map { |c| c.interpersonal.tenor }.sum / clauses.size.to_f
        avg_modality = clauses.map { |c| c.interpersonal.modality_weight }.sum / clauses.size.to_f
        mood_counts = clauses.map { |c| c.interpersonal.mood }.tally
        dominant_mood = mood_counts.max_by { |_, count| count }&.first || "declarative"

        process_types = clauses.flat_map { |c| c.ideational.process_type }.tally
        participants = clauses.flat_map { |c| c.ideational.participants.map(&:text) }.uniq

        Types::ConversationTurn.new(
          turn_id: turn_id,
          speaker: speaker,
          timestamp: timestamp,
          message_text: message_text,
          clauses: clauses,
          avg_tenor: avg_tenor,
          avg_modality: avg_modality,
          dominant_mood: dominant_mood,
          process_types: process_types,
          participants: participants,
          tenor_shift: nil
        )
      end

      def analyze_conversation(jsonl_path)
        raw_turns = load_jsonl(jsonl_path)

        @logger.send_message(
          message: "conversation_analysis_started",
          priority: Journald::LOG_INFO,
          turn_count: raw_turns.size,
          source_file: jsonl_path
        )

        puts "\n[INFO] Compiling #{raw_turns.size} conversation turns through SFL pipeline..."
        if PASS_ONE_ONLY
          puts "[INFO] Mode: PASS=1 — syntactic/ideational only (no LLM calls)"
        else
          puts "[INFO] Mode: Full pipeline — Pass 1 (spaCy) + Pass 2 (LLM annotation)"
        end
        puts "[INFO] Progress:"

        conversation_turns = raw_turns.each_with_index.map do |turn_data, idx|
          turn_id = idx + 1
          speaker = turn_data[:name]

          print "  Turn #{turn_id}/#{raw_turns.size} (#{speaker})... "
          $stdout.flush

          start_time = Time.now
          turn = compile_turn(turn_data, turn_id)
          elapsed = (Time.now - start_time).round(2)

          defaulted = turn.clauses.count { |c| c.interpersonal.annotation_source != "llm" }
          label = defaulted.zero? ? "OK" : "#{defaulted}/#{turn.clauses.size} DEFAULTED"
          puts "#{elapsed}s [tenor: #{turn.avg_tenor.round(2)} #{label}]"

          turn
        end
        puts ""

        all_clauses = conversation_turns.flat_map(&:clauses)
        total_defaulted = all_clauses.count { |c| c.interpersonal.annotation_source != "llm" }
        if total_defaulted.positive?
          pct = (total_defaulted * 100.0 / all_clauses.size).round(1)
          puts "[WARN] #{total_defaulted}/#{all_clauses.size} clauses (#{pct}%) carry fallback/stub interpersonal values — tenor/modality aggregates are biased toward 0.5. See the Data Quality section in the report."
        end

        tenor_tracker = Analysis::TenorTracker.new(conversation_turns)
        tenor_tracker.calculate_shifts

        speaker_profiles = Analysis::SpeakerProfiler.build_profiles(conversation_turns)

        correlation_analyzer = Analysis::CorrelationAnalyzer.new(conversation_turns)
        correlations = correlation_analyzer.correlate_process_tenor

        tenor_timeline = conversation_turns.map do |turn|
          {
            turn_id: turn.turn_id,
            timestamp: turn.timestamp.iso8601,
            speaker: turn.speaker,
            tenor: turn.avg_tenor,
            tenor_shift: turn.tenor_shift
          }
        end

        field_evolution = conversation_turns.map do |turn|
          {
            turn_id: turn.turn_id,
            timestamp: turn.timestamp.iso8601,
            dominant_process: turn.process_types.max_by { |_, count| count }&.first
          }
        end

        insights = generate_insights(conversation_turns, tenor_timeline, correlations)

        Types::AnalysisResult.new(
          metadata: {
            source_file: jsonl_path,
            turn_count: conversation_turns.size,
            speakers: conversation_turns.map(&:speaker).uniq,
            analyzed_at: Time.now.iso8601
          },
          turns: conversation_turns,
          speaker_profiles: speaker_profiles,
          tenor_timeline: tenor_timeline,
          field_evolution: field_evolution,
          correlations: correlations,
          insights: insights
        )
      end

      def generate_outputs(analysis_result, output_dir)
        FileUtils.mkdir_p(output_dir)

        csv_path = File.join(output_dir, "conversation_analysis.csv")
        csv_formatter = Formatters::CSVFormatter.new(analysis_result)
        File.write(csv_path, csv_formatter.render)
        @logger.send_message(
          message: "csv_output_generated",
          priority: Journald::LOG_INFO,
          path: csv_path
        )

        json_path = File.join(output_dir, "conversation_analysis.json")
        json_formatter = Formatters::JSONFormatter.new(analysis_result)
        File.write(json_path, json_formatter.render)
        @logger.send_message(
          message: "json_output_generated",
          priority: Journald::LOG_INFO,
          path: json_path
        )

        markdown_path = File.join(output_dir, "conversation_analysis.md")
        markdown_formatter = Formatters::MarkdownFormatter.new(analysis_result)
        File.write(markdown_path, markdown_formatter.render)
        @logger.send_message(
          message: "markdown_output_generated",
          priority: Journald::LOG_INFO,
          path: markdown_path
        )

        {
          csv: csv_path,
          json: json_path,
          markdown: markdown_path
        }
      end

      private

      def setup_database
        db = Database.connect(@database_url)
        Database.setup_extensions(db)
        migrator = Migrator.new(db)
        migrator.run_all
        db
      rescue Sequel::DatabaseError => e
        @logger.send_message(
          message: "database_setup_failed",
          priority: Journald::LOG_ERROR,
          error: e.message
        )
        raise
      end

      def parse_timestamp(timestamp_str)
        Time.parse(timestamp_str)
      rescue ArgumentError
        Time.now
      end

      def generate_insights(turns, tenor_timeline, correlations)
        insights = []

        tenor_values = tenor_timeline.map { |t| t[:tenor] }
        tenor_trend = tenor_values.last - tenor_values.first
        if tenor_trend > 0.1
          insights << "Conversation tenor increased by #{(tenor_trend * 100).round(1)}% (more formal/distant)"
        elsif tenor_trend < -0.1
          insights << "Conversation tenor decreased by #{(tenor_trend.abs * 100).round(1)}% (more casual/close)"
        end

        speaker_turn_counts = turns.map(&:speaker).tally
        if speaker_turn_counts.size > 1
          dominant_speaker = speaker_turn_counts.max_by { |_, count| count }.first
          insights << "#{dominant_speaker} contributed #{speaker_turn_counts[dominant_speaker]} of #{turns.size} turns"
        end

        if correlations[:modality_tenor_correlation]
          corr = correlations[:modality_tenor_correlation]
          if corr > 0.5
            insights << "Strong positive correlation between modality and tenor (r=#{corr.round(2)})"
          elsif corr < -0.5
            insights << "Strong negative correlation between modality and tenor (r=#{corr.round(2)})"
          end
        end

        insights
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.size != 2
    puts "Usage: #{$PROGRAM_NAME} <input.jsonl> <output_dir>"
    exit 1
  end

  input_jsonl = ARGV[0]
  output_dir = ARGV[1]

  unless File.exist?(input_jsonl)
    puts "Error: Input file not found: #{input_jsonl}"
    exit 1
  end

  analyzer = SFL::Compiler::ConversationAnalyzer.new
  analysis_result = analyzer.analyze_conversation(input_jsonl)
  outputs = analyzer.generate_outputs(analysis_result, output_dir)

  puts "\nAnalysis complete!"
  puts "Generated outputs:"
  outputs.each do |format, path|
    puts "  #{format.upcase}: #{path}"
  end
end