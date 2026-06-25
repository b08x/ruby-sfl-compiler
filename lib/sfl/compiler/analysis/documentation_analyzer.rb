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
        include Aggregations

        # @param pipeline [Pipeline]
        # @param clause_repo [ClauseRepository] needed only for store: true
        # @param on_progress [#call, nil] same event shape as
        #   ConversationAnalyzer's callback
        # @param on_turn_start [#call, nil] same event shape as
        #   ConversationAnalyzer's callback — fires before a section's
        #   compilation starts, not just after
        # @param stop_requested [#call, nil] same contract as
        #   ConversationAnalyzer's callback — polled once per section,
        #   never mid-section
        def initialize(pipeline:, clause_repo: nil, on_progress: nil, on_turn_start: nil, stop_requested: nil)
          @pipeline = pipeline
          @clause_repo = clause_repo
          @on_progress = on_progress
          @on_turn_start = on_turn_start
          @stop_requested = stop_requested
          @resume = pipeline.cache ? true : false
        end

        # @param path [String] a .md file or a directory of .md files
        # @param store [Boolean] persist clauses + embeddings
        # @param topics [Integer, nil] fixed topic count for LDA; 0 → HDP
        #   (auto-discover topic count, k: nil); nil = no topic modeling
        # @param resume [Boolean] reuse cached Pass 2 results
        # @param sprint_id [String, nil] when present, attaches a
        #   Gödel-encoded question graph to the report footer (see
        #   #sprint_metadata) — omitted entirely when nil
        # @return [Types::AnalysisResult]
        def analyze(path, store: false, topics: nil, resume: false, sprint_id: nil)
          @resume = resume
          sections = load_sections(path)
          total = sections.size

          # Pre-pass topic fit: runs on stub turns before compilation
          modeler = nil
          pre_turns = nil
          topic_labels = nil
          topic_shifts = []
          if topics && sections.size >= 3
            stub_turns = sections.each_with_index.map do |(section, mtime), idx|
              Types::ConversationTurn.new(
                turn_id: idx + 1,
                speaker: section.heading || section.file_id,
                timestamp: mtime,
                message_text: section.text,
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

          turns = []
          sections.each_with_index do |(section, mtime), idx|
            break if @stop_requested&.call

            turn_id = idx + 1
            @on_turn_start&.call(turn_id:, total:, speaker: section.heading || section.file_id)
            started = Time.now

            pre_turn = pre_turns&.[](idx)
            turn = compile_section(section, mtime, turn_id, store, pre_turn:, modeler:)

            report_progress(turn, total, Time.now - started)
            turns << turn
          end
          interrupted = turns.size < total

          TenorTracker.new(turns).calculate_shifts
          turns = CohesionAnalyzer.new.analyze(turns)
          profiles = SpeakerProfiler.build_profiles(turns)
          correlations = CorrelationAnalyzer.new(turns).correlate_process_tenor

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
              topics_enabled: !topic_labels.nil?,
              interrupted:,
              total:,
            }.merge(sprint_metadata(sprint_id)),
            turns:,
            speaker_profiles: profiles,
            tenor_timeline: timeline(turns),
            field_evolution: field_evolution(turns),
            correlations:,
            insights: generate_topic_insights(turns, topic_labels),
            key_moments: all_key_moments,
            example_passages: detect_example_passages(turns),
            topic_labels:,
            topic_evolution: topic_evolution(turns)
          )
        end

        # A fixed, canonical question set for a documentation sprint —
        # not yet content-derived or answer-tracked (that's
        # SprintOrchestrator's job, not built yet); this is the smallest
        # honest "questions were asked" graph a documentation report can
        # attach today. `{}` (no sprint_id) omits the footer entirely.
        # rubocop:disable Naming/AsciiIdentifiers -- QuestionGraph's own
        # API names this method with the umlaut throughout.
        private def sprint_metadata(sprint_id)
          return {} unless sprint_id

          questions = canonical_sprint_questions
          {
            sprint_id:,
            sprint_godel_number: QuestionGraph.new(questions).gödel_number,
            sprint_question_ids: questions.map { |q| q[:id] },
          }
        end
        # rubocop:enable Naming/AsciiIdentifiers

        private def canonical_sprint_questions
          [
            { id: :modality, text: "What is the average modality across this document?", dependencies: [] },
            {
              id: :data_quality,
              text: "Are fallback/stub annotations present that could bias these findings?",
              dependencies: [],
            },
            {
              id: :tenor_consistency,
              text: "Is tenor consistent across sections, or does it vary significantly?",
              dependencies: [],
            },
            {
              id: :overall_confidence,
              text: "Is this analysis reliable enough to ground synthesis on?",
              dependencies: %i[modality data_quality tenor_consistency],
            },
          ]
        end

        private def detect_key_moments(turns)
          moments = []

          # Significant Tenor Shifts (Formality Flow)
          turns.each_cons(2) do |prev, curr|
            shift = (curr.avg_tenor - prev.avg_tenor).round(3)
            next unless shift.abs > 0.15

            direction = shift.positive? ? "increased" : "decreased"
            moments << Types::KeyMoment.new(
              turn_id: curr.turn_id,
              type: "tenor_shift",
              magnitude: shift,
              description: "Formality #{direction} dramatically (+#{shift}) in section '#{curr.speaker}'"
            )
          end

          # Semantic anomalies
          turns.each do |curr|
            next unless curr.semantic_coherence_score
            next unless curr.semantic_coherence_score < 0.35

            moments << Types::KeyMoment.new(
              turn_id: curr.turn_id,
              type: "semantic_anomaly",
              magnitude: curr.semantic_coherence_score,
              description: "Section '#{curr.speaker}' is semantically anomalous relative to the document baseline (coherence: #{curr.semantic_coherence_score.round(3)})"
            )
          end

          moments
        end

        private def detect_example_passages(turns)
          passages = []

          # Most Formal Section
          most_formal = turns.max_by(&:avg_tenor)
          if most_formal
            passages << Types::ExamplePassage.new(
              label: "Most Formal Section",
              text: "#{most_formal.message_text[0..200]}...",
              speaker: most_formal.speaker,
              value: most_formal.avg_tenor,
              reason: "Highest formality score in the document"
            )
          end

          # Most Certain Section
          most_certain = turns.max_by(&:avg_modality)
          if most_certain
            passages << Types::ExamplePassage.new(
              label: "Most Assertive Section",
              text: "#{most_certain.message_text[0..200]}...",
              speaker: most_certain.speaker,
              value: most_certain.avg_modality,
              reason: "Highest certainty score; authoritative stance"
            )
          end

          passages
        end

        # @return [Array<[MarkdownLoader::Section, Time]>]
        private def load_sections(path)
          files = File.directory?(path) ? Dir.glob(File.join(path, "**", "*.{md,pdf}")) : [path]
          files.flat_map do |file|
            mtime = File.mtime(file)
            loader = File.extname(file).casecmp(".pdf").zero? ? PdfLoader : MarkdownLoader
            loader.load(file).map { |section| [section, mtime] }
          end
        end

        # `topics: 0` requests HDP (auto-discover the topic count) rather
        # than a fixed-k LDA — Tomoto's HDP constructor takes no `k:` at
        # all, so this maps the CLI's single `--topics N` integer flag onto
        # TopicModeler's `k: nil` HDP switch without adding a second flag.
        private def topic_k(topics)
          topics.zero? ? nil : topics
        end

        private def compile_section(section, mtime, turn_id, store, pre_turn: nil, modeler: nil)
          @clause_repo.delete_by_document(section.document_id) if store && @clause_repo

          semantic_coherence_score = pre_turn&.semantic_coherence_score
          topic_info = if pre_turn && pre_turn.dominant_topic && modeler
            label = modeler.topic_labels[pre_turn.dominant_topic]&.first(3)&.join(", ")
            { id: pre_turn.dominant_topic, label: }
          else
            nil
          end

          compile_kwargs = { document_id: section.document_id, store:, embed: store, resume: @resume }
          compile_kwargs[:topic] = topic_info if topic_info
          compile_kwargs[:semantic_coherence_score] = semantic_coherence_score if semantic_coherence_score

          clauses = @pipeline.compile(section.text, **compile_kwargs)

          Types::ConversationTurn.new(
            turn_id:,
            speaker: section.heading || section.file_id,
            timestamp: mtime,
            message_text: section.text,
            clauses:,
            avg_tenor: mean(clauses.map { |c| c.interpersonal.tenor }),
            avg_modality: mean(clauses.map { |c| c.interpersonal.modality_weight }),
            dominant_mood: clauses.map { |c| c.interpersonal.mood }.tally
              .max_by { |_, count| count }&.first || "declarative",
            process_types: clauses.map { |c| c.ideational.process_type }.tally,
            participants: clauses.flat_map { |c| c.ideational.participants.map(&:text) }.uniq,
            tenor_shift: nil,
            topic_distribution: pre_turn&.topic_distribution,
            dominant_topic: pre_turn&.dominant_topic,
            semantic_coherence_score: semantic_coherence_score
          )
        end

        private def report_progress(turn, total, elapsed)
          return unless @on_progress

          defaulted = turn.clauses.count { |c| c.interpersonal.annotation_source != "llm" }
          @on_progress.call(
            turn_id: turn.turn_id, total:, speaker: turn.speaker,
            elapsed: elapsed.round(2), clause_count: turn.clauses.size,
            defaulted:
          )
        end

        private def timeline(turns)
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

        private def generate_topic_insights(turns, topic_labels)
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
      end
    end
  end
end
