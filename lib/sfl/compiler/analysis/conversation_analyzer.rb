# frozen_string_literal: true

require "json"
require "time"

module SFL
  module Compiler
    module Analysis
      # Compiles a JSONL conversation ({name, send_date, mes} per line)
      # through the SFL pipeline and aggregates tenor/field analysis.
      # UI-agnostic: no printing, no exiting, no ENV. Progress is reported
      # through the optional on_progress callback.
      class ConversationAnalyzer
        # @param pipeline [Pipeline]
        # @param pass_one_only [Boolean] skip Pass 2; stub interpersonal
        #   values with annotation_source "stub"
        # @param on_progress [#call, nil] receives one Hash per turn:
        #   {turn_id:, total:, speaker:, elapsed:, clause_count:, defaulted:}
        def initialize(pipeline:, pass_one_only: false, on_progress: nil)
          @pipeline = pipeline
          @pass_one_only = pass_one_only
          @on_progress = on_progress
        end

        # @param jsonl_path [String]
        # @return [Types::AnalysisResult]
        def analyze(jsonl_path)
          raw_turns = load_jsonl(jsonl_path)
          total = raw_turns.size

          turns = raw_turns.each_with_index.map do |turn_data, idx|
            started = Time.now
            turn = compile_turn(turn_data, idx + 1)
            report_progress(turn, total, Time.now - started)
            turn
          end

          TenorTracker.new(turns).calculate_shifts
          profiles = SpeakerProfiler.build_profiles(turns)
          correlations = CorrelationAnalyzer.new(turns).correlate_process_tenor
          timeline = tenor_timeline(turns)

          Types::AnalysisResult.new(
            metadata: {
              conversation_id: File.basename(jsonl_path, ".*"),
              source_file: jsonl_path,
              turn_count: turns.size,
              speakers: turns.map(&:speaker).uniq,
              analyzed_at: Time.now.iso8601
            },
            turns: turns,
            speaker_profiles: profiles,
            tenor_timeline: timeline,
            field_evolution: field_evolution(turns),
            correlations: correlations,
            insights: generate_insights(turns, timeline, correlations)
          )
        end

        private

        def report_progress(turn, total, elapsed)
          return unless @on_progress

          defaulted = turn.clauses.count { |c| c.interpersonal.annotation_source != "llm" }
          @on_progress.call(
            turn_id: turn.turn_id, total: total, speaker: turn.speaker,
            elapsed: elapsed.round(2), clause_count: turn.clauses.size,
            defaulted: defaulted
          )
        end

        def load_jsonl(path)
          File.readlines(path).filter_map do |line|
            JSON.parse(line.strip, symbolize_names: true)
          rescue JSON::ParserError
            nil
          end
        end

        def compile_turn(turn_data, turn_id)
          clauses = compile_clauses(turn_data[:mes], "turn-#{turn_id}")

          avg_tenor = mean(clauses.map { |c| c.interpersonal.tenor })
          avg_modality = mean(clauses.map { |c| c.interpersonal.modality_weight })
          mood_counts = clauses.map { |c| c.interpersonal.mood }.tally

          Types::ConversationTurn.new(
            turn_id: turn_id,
            speaker: turn_data[:name],
            timestamp: parse_timestamp(turn_data[:send_date]),
            message_text: turn_data[:mes],
            clauses: clauses,
            avg_tenor: avg_tenor,
            avg_modality: avg_modality,
            dominant_mood: mood_counts.max_by { |_, count| count }&.first || "declarative",
            process_types: clauses.map { |c| c.ideational.process_type }.tally,
            participants: clauses.flat_map { |c| c.ideational.participants.map(&:text) }.uniq,
            tenor_shift: nil
          )
        end

        def compile_clauses(text, document_id)
          unless @pass_one_only
            return @pipeline.compile(text, document_id: document_id, store: false, embed: false)
          end

          @pipeline.compile_pass_one(text, document_id: document_id)
            .map.with_index do |(syntactic, ideational), idx|
              Types::AnnotatedClause.new(
                id: "#{document_id}-clause-#{idx + 1}",
                text: syntactic.text,
                syntactic: syntactic,
                ideational: ideational,
                interpersonal: Types::InterpersonalPayload.new(
                  clause_id: "#{document_id}-clause-#{idx + 1}",
                  mood: "declarative", modality_weight: 0.5, tenor: 0.5,
                  speaker_attitude: nil,
                  reasoning: "Pass 2 skipped — placeholder values",
                  annotation_source: "stub"
                ),
                document_id: document_id,
                compiled_at: Time.now
              )
            end
        end

        def tenor_timeline(turns)
          turns.map do |turn|
            { turn_id: turn.turn_id, timestamp: turn.timestamp.iso8601,
              speaker: turn.speaker, tenor: turn.avg_tenor,
              tenor_shift: turn.tenor_shift }
          end
        end

        def field_evolution(turns)
          turns.map do |turn|
            { turn_id: turn.turn_id, timestamp: turn.timestamp.iso8601,
              dominant_process: turn.process_types.max_by { |_, count| count }&.first }
          end
        end

        def generate_insights(turns, timeline, correlations)
          insights = []

          tenors = timeline.map { |t| t[:tenor] }
          trend = tenors.last - tenors.first
          if trend > 0.1
            insights << "Conversation tenor increased by #{(trend * 100).round(1)}% (more formal/distant)"
          elsif trend < -0.1
            insights << "Conversation tenor decreased by #{(trend.abs * 100).round(1)}% (more casual/close)"
          end

          counts = turns.map(&:speaker).tally
          if counts.size > 1
            top = counts.max_by { |_, count| count }.first
            insights << "#{top} contributed #{counts[top]} of #{turns.size} turns"
          end

          if (corr = correlations[:modality_tenor_correlation])
            if corr > 0.5
              insights << "Strong positive correlation between modality and tenor (r=#{corr.round(2)})"
            elsif corr < -0.5
              insights << "Strong negative correlation between modality and tenor (r=#{corr.round(2)})"
            end
          end

          insights
        end

        def parse_timestamp(value)
          Time.parse(value.to_s)
        rescue ArgumentError
          Time.now
        end

        def mean(values)
          return 0.5 if values.empty?

          values.sum / values.size.to_f
        end
      end
    end
  end
end
