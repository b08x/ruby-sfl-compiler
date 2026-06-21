# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Compiles markdown documentation through the SFL pipeline,
      # mapping sections onto conversation turns (speaker = heading) so
      # the existing profiling/correlation/formatting machinery applies:
      # SpeakerProfiler yields per-section profiles, the tenor timeline
      # becomes formality flow through the document.
      #
      # store: true persists clauses + embeddings for later `context`
      # queries; each section's stable document_id is deleted first so
      # re-ingestion is idempotent.
      class DocumentationAnalyzer
        # @param pipeline [Pipeline]
        # @param clause_repo [ClauseRepository] needed only for store: true
        # @param on_progress [#call, nil] same event shape as
        #   ConversationAnalyzer's callback
        def initialize(pipeline:, clause_repo: nil, on_progress: nil)
          @pipeline = pipeline
          @clause_repo = clause_repo
          @on_progress = on_progress
          @resume = pipeline.cache ? true : false
        end

        # @param path [String] a .md file or a directory of .md files
        # @param store [Boolean] persist clauses + embeddings
        # @param topics [Integer, nil] number of topics for LDA; nil = no topic modeling
        # @param resume [Boolean] reuse cached Pass 2 results
        # @return [Types::AnalysisResult]
        def analyze(path, store: false, topics: nil, resume: false)
          @resume = resume
          sections = load_sections(path)
          total = sections.size

          turns = sections.each_with_index.map do |(section, mtime), idx|
            started = Time.now
            turn = compile_section(section, mtime, idx + 1, store)
            report_progress(turn, total, Time.now - started)
            turn
          end

          TenorTracker.new(turns).calculate_shifts
          turns = CohesionAnalyzer.new.analyze(turns)
          profiles = SpeakerProfiler.build_profiles(turns)
          correlations = CorrelationAnalyzer.new(turns).correlate_process_tenor

          # Topic modeling (optional)
          topic_labels = nil
          topic_shifts = []
          if topics && turns.size >= 3
            modeler = TopicModeler.new(k: topics)
            modeler.fit(turns)
            topic_labels = modeler.topic_labels
            topic_shifts = modeler.detect_topic_shifts
          end

          all_key_moments = detect_key_moments(turns)
          all_key_moments.concat(topic_shifts)

          Types::AnalysisResult.new(
            metadata: {
              conversation_id: File.basename(path, ".*"),
              source_file: path,
              turn_count: turns.size,
              speakers: turns.map(&:speaker).uniq,
              analyzed_at: Time.now.iso8601,
              unit_label: "Section",
              actor_label: "Section",
              actors_list_label: "Headings",
              topics_enabled: !topic_labels.nil?
            },
            turns: turns,
            speaker_profiles: profiles,
            tenor_timeline: timeline(turns),
            field_evolution: field_evolution(turns),
            correlations: correlations,
            insights: generate_topic_insights(turns, topic_labels),
            key_moments: all_key_moments,
            example_passages: detect_example_passages(turns),
            topic_labels: topic_labels,
            topic_evolution: topic_evolution(turns)
          )
        end

        private

        def detect_key_moments(turns)
          moments = []
          
          # Significant Tenor Shifts (Formality Flow)
          turns.each_cons(2) do |prev, curr|
            shift = (curr.avg_tenor - prev.avg_tenor).round(3)
            if shift.abs > 0.15
              direction = shift.positive? ? "increased" : "decreased"
              moments << Types::KeyMoment.new(
                turn_id: curr.turn_id,
                type: "tenor_shift",
                magnitude: shift,
                description: "Formality #{direction} dramatically (+#{shift}) in section '#{curr.speaker}'"
              )
            end
          end

          moments
        end

        def detect_example_passages(turns)
          passages = []
          
          # Most Formal Section
          most_formal = turns.max_by(&:avg_tenor)
          passages << Types::ExamplePassage.new(
            label: "Most Formal Section",
            text: most_formal.message_text[0..200] + "...",
            speaker: most_formal.speaker,
            value: most_formal.avg_tenor,
            reason: "Highest formality score in the document"
          ) if most_formal

          # Most Certain Section
          most_certain = turns.max_by(&:avg_modality)
          passages << Types::ExamplePassage.new(
            label: "Most Assertive Section",
            text: most_certain.message_text[0..200] + "...",
            speaker: most_certain.speaker,
            value: most_certain.avg_modality,
            reason: "Highest certainty score; authoritative stance"
          ) if most_certain

          passages
        end

        # @return [Array<[MarkdownLoader::Section, Time]>]
        def load_sections(path)
          files = File.directory?(path) ? Dir.glob(File.join(path, "**", "*.md")).sort : [path]
          files.flat_map do |file|
            mtime = File.mtime(file)
            MarkdownLoader.load(file).map { |section| [section, mtime] }
          end
        end

        def compile_section(section, mtime, turn_id, store)
          @clause_repo.delete_by_document(section.document_id) if store

          clauses = @pipeline.compile(
            section.text,
            document_id: section.document_id,
            store: store, embed: store,
            resume: @resume
          )

          Types::ConversationTurn.new(
            turn_id: turn_id,
            speaker: section.heading || section.file_id,
            timestamp: mtime,
            message_text: section.text,
            clauses: clauses,
            avg_tenor: mean(clauses.map { |c| c.interpersonal.tenor }),
            avg_modality: mean(clauses.map { |c| c.interpersonal.modality_weight }),
            dominant_mood: clauses.map { |c| c.interpersonal.mood }.tally
              .max_by { |_, count| count }&.first || "declarative",
            process_types: clauses.map { |c| c.ideational.process_type }.tally,
            participants: clauses.flat_map { |c| c.ideational.participants.map(&:text) }.uniq,
            tenor_shift: nil
          )
        end

        def report_progress(turn, total, elapsed)
          return unless @on_progress

          defaulted = turn.clauses.count { |c| c.interpersonal.annotation_source != "llm" }
          @on_progress.call(
            turn_id: turn.turn_id, total: total, speaker: turn.speaker,
            elapsed: elapsed.round(2), clause_count: turn.clauses.size,
            defaulted: defaulted
          )
        end

        def timeline(turns)
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

        def topic_evolution(turns)
          turns.filter_map do |turn|
            next unless turn.dominant_topic

            { turn_id: turn.turn_id, timestamp: turn.timestamp.iso8601,
              dominant_topic: turn.dominant_topic,
              topic_distribution: turn.topic_distribution }
          end
        end

        def generate_topic_insights(turns, topic_labels)
          return [] unless topic_labels && topic_labels.any?

          insights = []
          topic_count = topic_labels.size
          insights << "#{topic_count} topics identified across the document"

          dominant_topics = turns.filter_map(&:dominant_topic).tally
          if dominant_topics.any?
            top_topic = dominant_topics.max_by { |_, count| count }.first
            top_words = topic_labels[top_topic]&.first(3)&.join(", ") || "topic #{top_topic}"
            insights << "Most prominent topic: #{top_words} (#{dominant_topics[top_topic]} sections)"
          end

          insights
        end

        def mean(values)
          return 0.5 if values.empty?

          values.sum / values.size.to_f
        end
      end
    end
  end
end
