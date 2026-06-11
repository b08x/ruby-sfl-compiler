#!/usr/bin/env ruby
# frozen_string_literal: true

# Conversation Analysis Template Script
#
# Loads JSONL conversation data, runs SFL compilation on each turn,
# and generates multi-format analysis outputs (CSV, JSON, Markdown).
#
# Usage:
#   ruby conversation_analysis_template.rb <input.jsonl> <output_dir>

require "bundler/setup"
require "dotenv/load"  # Load environment variables from .env
require "json"
require "time"
require "journald/logger"
require "dspy"  # Required for DSPy.configure
require_relative "../../../lib/sfl-compiler"

# Configure SFL Compiler from environment variables
SFL::Compiler.configure do |c|
  c.database_url = ENV.fetch("DATABASE_URL", "postgresql:///sfl_compiler_dev")
  c.spacy_model  = ENV.fetch("SPACY_MODEL", "en_core_web_sm")
  c.dspy_provider = ENV.fetch("DSPY_PROVIDER", "openai/gpt-4o-mini")
end

# Configure DSPy.rb for Pass 2 (LLM annotation)
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
  ENV.fetch("OPENROUTER_API_KEY", nil)  # Default to OpenRouter
end

if api_key && !api_key.empty?
  DSPy.configure do |c|
    c.lm = DSPy::LM.new(provider,
      api_key: api_key,
      structured_outputs: true)
  end
  puts "[INFO] DSPy configured with provider: #{provider}"
else
  puts "[WARN] No API key found for #{provider} - Pass 2 will use circuit breaker defaults"
end

module SFL
  module Compiler
    # Orchestrates conversation analysis from JSONL to formatted outputs
    class ConversationAnalyzer
      attr_reader :db, :pipeline, :logger

      def initialize(database_url: nil)
        @database_url = database_url || ENV.fetch("DATABASE_URL", "postgresql:///sfl_compiler_dev")
        @logger = Journald::Logger.new("conversation-analyzer")
        setup_database
        @pipeline = SFL::Compiler::Pipeline.new(db: @db)
      end

      # Load and parse JSONL conversation file
      #
      # @param jsonl_path [String] Path to JSONL file
      # @return [Array<Hash>] Parsed conversation turns
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

      # Compile a single conversation turn through SFL pipeline
      #
      # @param turn_data [Hash] Raw turn data from JSONL
      # @param turn_id [Integer] Turn sequence number
      # @return [Types::ConversationTurn]
      def compile_turn(turn_data, turn_id)
        message_text = turn_data[:mes]
        speaker = turn_data[:name]
        timestamp = parse_timestamp(turn_data[:send_date])

        # Run through SFL compiler
        clauses = @pipeline.compile(
          message_text,
          document_id: "turn-#{turn_id}",
          store: false,  # Don't persist individual turns by default
          embed: false   # Skip embedding for analysis template
        )

        # Aggregate metrics across clauses
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

      # Analyze full conversation and generate AnalysisResult
      #
      # @param jsonl_path [String] Path to JSONL conversation file
      # @return [Types::AnalysisResult]
      def analyze_conversation(jsonl_path)
        raw_turns = load_jsonl(jsonl_path)

        @logger.send_message(
          message: "conversation_analysis_started",
          priority: Journald::LOG_INFO,
          turn_count: raw_turns.size,
          source_file: jsonl_path
        )

        # Compile each turn
        conversation_turns = raw_turns.each_with_index.map do |turn_data, idx|
          compile_turn(turn_data, idx + 1)
        end

        # Run analysis modules
        tenor_tracker = Analysis::TenorTracker.new(conversation_turns)
        tenor_tracker.calculate_shifts

        speaker_profiles = Analysis::SpeakerProfiler.build_profiles(conversation_turns)

        correlation_analyzer = Analysis::CorrelationAnalyzer.new(conversation_turns)
        correlations = correlation_analyzer.correlate_process_tenor

        # Tenor timeline (tenor values over time)
        tenor_timeline = conversation_turns.map do |turn|
          {
            turn_id: turn.turn_id,
            timestamp: turn.timestamp.iso8601,
            speaker: turn.speaker,
            tenor: turn.avg_tenor,
            tenor_shift: turn.tenor_shift
          }
        end

        # Field evolution (process type progression)
        field_evolution = conversation_turns.map do |turn|
          {
            turn_id: turn.turn_id,
            timestamp: turn.timestamp.iso8601,
            dominant_process: turn.process_types.max_by { |_, count| count }&.first
          }
        end

        # Generate insights
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

      # Generate outputs in all formats
      #
      # @param analysis_result [Types::AnalysisResult]
      # @param output_dir [String] Directory to write output files
      def generate_outputs(analysis_result, output_dir)
        FileUtils.mkdir_p(output_dir)

        # CSV output
        csv_path = File.join(output_dir, "conversation_analysis.csv")
        csv_formatter = Formatters::CSVFormatter.new(analysis_result)
        File.write(csv_path, csv_formatter.render)
        @logger.send_message(
          message: "csv_output_generated",
          priority: Journald::LOG_INFO,
          path: csv_path
        )

        # JSON output
        json_path = File.join(output_dir, "conversation_analysis.json")
        json_formatter = Formatters::JSONFormatter.new(analysis_result)
        File.write(json_path, json_formatter.render)
        @logger.send_message(
          message: "json_output_generated",
          priority: Journald::LOG_INFO,
          path: json_path
        )

        # Markdown output
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
        @db = Database.connect(@database_url)
        Database.setup_extensions(@db)

        # Run migrations if needed
        migrator = Migrator.new(@db)
        migrator.run_all
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

        # Tenor insights
        tenor_values = tenor_timeline.map { |t| t[:tenor] }
        tenor_trend = tenor_values.last - tenor_values.first
        if tenor_trend > 0.1
          insights << "Conversation tenor increased by #{(tenor_trend * 100).round(1)}% (more formal/distant)"
        elsif tenor_trend < -0.1
          insights << "Conversation tenor decreased by #{(tenor_trend.abs * 100).round(1)}% (more casual/close)"
        end

        # Speaker dominance
        speaker_turn_counts = turns.map(&:speaker).tally
        if speaker_turn_counts.size > 1
          dominant_speaker = speaker_turn_counts.max_by { |_, count| count }.first
          insights << "#{dominant_speaker} contributed #{speaker_turn_counts[dominant_speaker]} of #{turns.size} turns"
        end

        # Correlation insights
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

# CLI execution
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
