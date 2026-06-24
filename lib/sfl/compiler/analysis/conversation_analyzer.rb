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
        include Aggregations

        # @param pipeline [Pipeline]
        # @param pass_one_only [Boolean] skip Pass 2; stub interpersonal
        #   values with annotation_source "stub"
        # @param on_progress [#call, nil] receives one Hash per turn,
        #   after it finishes: {turn_id:, total:, speaker:, elapsed:,
        #   clause_count:, defaulted:}
        # @param on_turn_start [#call, nil] receives one Hash per turn,
        #   before compilation starts: {turn_id:, total:, speaker:} — a
        #   single turn's Pass 1 + Pass 2 can take 20-60s, so this fires
        #   immediately rather than leaving the caller with no signal
        #   until the (much later) on_progress callback
        def initialize(pipeline:, pass_one_only: false, on_progress: nil, on_turn_start: nil)
          @pipeline = pipeline
          @pass_one_only = pass_one_only
          @on_progress = on_progress
          @on_turn_start = on_turn_start
          @resume = pipeline.cache ? true : false
        end

        # @param jsonl_path [String]
        # @param topics [Integer, nil] fixed topic count for LDA; 0 → HDP
        #   (auto-discover topic count, k: nil); nil = no topic modeling
        # @param resume [Boolean] reuse cached Pass 2 results
        # @return [Types::AnalysisResult]
        def analyze(jsonl_path, topics: nil, resume: false)
          @resume = resume
          raw_turns = load_jsonl(jsonl_path)
          total = raw_turns.size

          # Topic modeling (optional pre-pass)
          modeler = nil
          pre_turns = nil
          topic_labels = nil
          topic_shifts = []
          if topics && raw_turns.size >= 3
            stub_turns = raw_turns.each_with_index.map do |turn_data, idx|
              Types::ConversationTurn.new(
                turn_id: idx + 1,
                speaker: turn_data[:name],
                timestamp: parse_timestamp(turn_data[:send_date]),
                message_text: turn_data[:mes],
                clauses: [],
                avg_tenor: 0.5,
                avg_modality: 0.5,
                dominant_mood: "declarative",
                process_types: {},
                participants: [],
                tenor_shift: nil,
                semantic_coherence_score: nil
              )
            end
            modeler = TopicModeler.new(k: topic_k(topics))
            modeler.fit(stub_turns)
            pre_turns = modeler.turns
            topic_labels = modeler.topic_labels
            topic_shifts = modeler.detect_topic_shifts
          end

          turns = raw_turns.each_with_index.map do |turn_data, idx|
            turn_id = idx + 1
            @on_turn_start&.call(turn_id:, total:, speaker: turn_data[:name])
            started = Time.now
            
            pre_turn = pre_turns&.[](idx)
            turn = compile_turn(turn_data, turn_id, pre_turn:, modeler:)
            
            report_progress(turn, total, Time.now - started)
            turn
          end

          TenorTracker.new(turns).calculate_shifts
          turns = CohesionAnalyzer.new.analyze(turns)
          profiles = SpeakerProfiler.build_profiles(turns)
          correlations = CorrelationAnalyzer.new(turns).correlate_process_tenor
          timeline = tenor_timeline(turns)

          all_key_moments = detect_key_moments(turns)
          all_key_moments.concat(topic_shifts)

          Types::AnalysisResult.new(
            metadata: {
              conversation_id: File.basename(jsonl_path, ".*"),
              source_file: jsonl_path,
              turn_count: turns.size,
              speakers: turns.map(&:speaker).uniq,
              analyzed_at: Time.now.iso8601,
              topics_enabled: !topic_labels.nil?,
            },
            turns:,
            speaker_profiles: profiles,
            tenor_timeline: timeline,
            field_evolution: field_evolution(turns),
            correlations:,
            insights: generate_insights(turns, timeline, correlations, topic_labels),
            key_moments: all_key_moments,
            example_passages: detect_example_passages(turns),
            topic_labels:,
            topic_evolution: topic_evolution(turns)
          )
        end

        private def detect_key_moments(turns)
          moments = []

          # Significant Tenor Shifts
          turns.each_cons(2) do |prev, curr|
            shift = (curr.avg_tenor - prev.avg_tenor).round(3)
            next unless shift.abs > 0.15

            direction = shift.positive? ? "increased" : "decreased"
            moments << Types::KeyMoment.new(
              turn_id: curr.turn_id,
              type: "tenor_shift",
              magnitude: shift,
              description: "Formality #{direction} dramatically (+#{shift}) between #{prev.speaker} and #{curr.speaker}"
            )

            # Significant Modality Shifts
            shift = (curr.avg_modality - prev.avg_modality).round(3)
            next unless shift.abs > 0.3

            direction = shift.positive? ? "increased" : "decreased"
            moments << Types::KeyMoment.new(
              turn_id: curr.turn_id,
              type: "modality_shift",
              magnitude: shift,
              description: "Certainty #{direction} significantly (+#{shift}) in #{curr.speaker}'s response"
            )
          end

          # Semantic/Deflation Anomalies
          turns.each do |curr|
            next unless curr.semantic_coherence_score
            next unless curr.semantic_coherence_score < 0.35

            # deflation move features: interrogative/imperative mood, hedge/low modality, or low tenor
            is_deflation = curr.dominant_mood == "interrogative" ||
                           curr.dominant_mood == "imperative" ||
                           curr.avg_modality < 0.4 ||
                           curr.avg_tenor < 0.4

            if is_deflation
              moments << Types::KeyMoment.new(
                turn_id: curr.turn_id,
                type: "deflation_anomaly",
                magnitude: curr.semantic_coherence_score,
                description: "Turn #{curr.turn_id} by #{curr.speaker} contains a semantically anomalous deflation move " \
                  "(coherence: #{curr.semantic_coherence_score.round(3)}, mood: #{curr.dominant_mood}, " \
                  "modality: #{curr.avg_modality.round(3)}, tenor: #{curr.avg_tenor.round(3)})"
              )
            else
              moments << Types::KeyMoment.new(
                turn_id: curr.turn_id,
                type: "semantic_anomaly",
                magnitude: curr.semantic_coherence_score,
                description: "Turn #{curr.turn_id} by #{curr.speaker} is semantically anomalous " \
                  "relative to the conversation baseline (coherence: #{curr.semantic_coherence_score.round(3)})"
              )
            end
          end

          moments
        end

        private def detect_example_passages(turns)
          passages = []

          # Most Formal
          most_formal = turns.max_by(&:avg_tenor)
          if most_formal
            passages << Types::ExamplePassage.new(
              label: "Most Formal",
              text: most_formal.message_text,
              speaker: most_formal.speaker,
              value: most_formal.avg_tenor,
              reason: "Highest tenor (formality) score in the conversation"
            )
          end

          # Most Casual
          most_casual = turns.min_by(&:avg_tenor)
          if most_casual
            passages << Types::ExamplePassage.new(
              label: "Most Casual",
              text: most_casual.message_text,
              speaker: most_casual.speaker,
              value: most_casual.avg_tenor,
              reason: "Lowest tenor score; uses informal register"
            )
          end

          # Most Certain
          most_certain = turns.max_by(&:avg_modality)
          if most_certain
            passages << Types::ExamplePassage.new(
              label: "Most Certain",
              text: most_certain.message_text,
              speaker: most_certain.speaker,
              value: most_certain.avg_modality,
              reason: "Highest modality weight; assertive and definitive language"
            )
          end

          # Most Uncertain/Hedged
          most_hedged = turns.min_by(&:avg_modality)
          if most_hedged
            passages << Types::ExamplePassage.new(
              label: "Most Hedged",
              text: most_hedged.message_text,
              speaker: most_hedged.speaker,
              value: most_hedged.avg_modality,
              reason: "Lowest modality weight; frequent use of hedging or uncertainty"
            )
          end

          passages
        end

        private def report_progress(turn, total, elapsed)
          return unless @on_progress

          defaulted = turn.clauses.count { |c| c.interpersonal.annotation_source != "llm" }
          @on_progress.call(
            turn_id: turn.turn_id, total:, speaker: turn.speaker,
            elapsed: elapsed.round(2), clause_count: turn.clauses.size,
            defaulted:, turn:
          )
        end

        # Skips lines that parse as valid JSON but aren't turn-shaped —
        # e.g. SillyTavern *group chat* exports prepend a
        # {chat_metadata:, user_name:, character_name:} header record
        # before the actual {name:, mes:, send_date:, ...} turns, which
        # JSON::ParserError can't catch since it's syntactically valid.
        private def load_jsonl(path)
          File.readlines(path).filter_map do |line|
            turn = JSON.parse(line.strip, symbolize_names: true)
            turn if turn.is_a?(Hash) && turn[:mes]
          rescue JSON::ParserError
            nil
          end
        end

        private def compile_turn(turn_data, turn_id, pre_turn: nil, modeler: nil)
          semantic_coherence_score = pre_turn&.semantic_coherence_score
          topic_info = if pre_turn && pre_turn.dominant_topic && modeler
            label = modeler.topic_labels[pre_turn.dominant_topic]&.first
            { id: pre_turn.dominant_topic, label: label }
          else
            nil
          end

          clauses = compile_clauses(
            turn_data[:mes],
            "turn-#{turn_id}",
            semantic_coherence_score: semantic_coherence_score,
            topic: topic_info
          )

          avg_tenor = mean(clauses.map { |c| c.interpersonal.tenor })
          avg_modality = mean(clauses.map { |c| c.interpersonal.modality_weight })
          mood_counts = clauses.map { |c| c.interpersonal.mood }.tally

          Types::ConversationTurn.new(
            turn_id:,
            speaker: turn_data[:name],
            timestamp: parse_timestamp(turn_data[:send_date]),
            message_text: turn_data[:mes],
            clauses:,
            avg_tenor:,
            avg_modality:,
            dominant_mood: mood_counts.max_by { |_, count| count }&.first || "declarative",
            process_types: clauses.map { |c| c.ideational.process_type }.tally,
            participants: clauses.flat_map { |c| c.ideational.participants.map(&:text) }.uniq,
            tenor_shift: nil,
            topic_distribution: pre_turn&.topic_distribution,
            dominant_topic: pre_turn&.dominant_topic,
            semantic_coherence_score: semantic_coherence_score
          )
        end

        private def compile_clauses(text, document_id, semantic_coherence_score: nil, topic: nil)
          unless @pass_one_only
            kwargs = { document_id:, store: false, embed: false, resume: @resume }
            kwargs[:topic] = topic unless topic.nil?
            kwargs[:semantic_coherence_score] = semantic_coherence_score unless semantic_coherence_score.nil?
            return @pipeline.compile(text, **kwargs)
          end

          @pipeline.compile_pass_one(text, document_id:)
            .map.with_index do |(syntactic, ideational), idx|
              Types::AnnotatedClause.new(
                id: "#{document_id}-clause-#{idx + 1}",
                text: syntactic.text,
                syntactic:,
                ideational:,
                interpersonal: Types::InterpersonalPayload.new(
                  clause_id: "#{document_id}-clause-#{idx + 1}",
                  mood: "declarative", modality_weight: 0.5, tenor: 0.5,
                  speaker_attitude: nil,
                  reasoning: "Pass 2 skipped — placeholder values",
                  annotation_source: "stub"
                ),
                document_id:,
                compiled_at: Time.now
              )
            end
        end

        private def tenor_timeline(turns)
          turns.map do |turn|
            {
              turn_id: turn.turn_id,
              timestamp: turn.timestamp.iso8601,
              speaker: turn.speaker,
              tenor: turn.avg_tenor,
              tenor_shift: turn.tenor_shift,
            }
          end
        end

        private def field_evolution(turns)
          turns.map do |turn|
            {
              turn_id: turn.turn_id,
              timestamp: turn.timestamp.iso8601,
              dominant_process: turn.process_types.max_by { |_, count| count }&.first,
            }
          end
        end

        private def topic_evolution(turns)
          turns.filter_map do |turn|
            next unless turn.dominant_topic

            {
              turn_id: turn.turn_id,
              timestamp: turn.timestamp.iso8601,
              dominant_topic: turn.dominant_topic,
              topic_distribution: turn.topic_distribution,
            }
          end
        end

        private def generate_insights(turns, timeline, correlations, topic_labels = nil)
          insights = []

          return insights if turns.empty?

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

          if topic_labels && topic_labels.any?
            topic_count = topic_labels.size
            insights << "#{topic_count} topics identified across the conversation"

            dominant_topics = turns.filter_map(&:dominant_topic).tally
            if dominant_topics.any?
              top_topic = dominant_topics.max_by { |_, count| count }.first
              top_words = topic_labels[top_topic]&.first(3)&.join(", ") || "topic #{top_topic}"
              insights << "Most prominent topic: #{top_words} (#{dominant_topics[top_topic]} turns)"
            end
          end

          insights
        end

        private def parse_timestamp(value)
          Time.parse(value.to_s)
        rescue ArgumentError
          Time.now
        end

        # `topics: 0` requests HDP (auto-discover the topic count) rather
        # than a fixed-k LDA — mirrors DocumentationAnalyzer's #topic_k.
        private def topic_k(topics)
          topics.zero? ? nil : topics
        end
      end
    end
  end
end
