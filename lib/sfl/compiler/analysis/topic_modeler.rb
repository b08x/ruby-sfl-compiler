# frozen_string_literal: true

require "tomoto"
require "pragmatic_tokenizer"

module SFL
  module Compiler
    module Analysis
      # TopicModeler — assigns topic distributions to conversation turns
      # or documentation sections using tomoto (LDA/HDP).
      #
      # Uses PragmaticTokenizer for lightweight tokenization (no spaCy
      # round-trip) with topic-modeling-specific preprocessing: lowercase,
      # stem, strip stopwords, drop punctuation/numbers.
      #
      # Two operating modes:
      #   - Fixed-k LDA: caller specifies number of topics
      #   - HDP: hierarchical Dirichlet process auto-discovers topic count
      #
      # Usage:
      #   modeler = Analysis::TopicModeler.new(k: 10)
      #   modeler.fit(turns)
      #   labels = modeler.topic_labels        # { 0 => ["sandbox", "security"], ... }
      #   shifts = modeler.detect_topic_shifts  # [{ turn_id: 5, from: 0, to: 3, ... }]
      #
      class TopicModeler
        # PragmaticTokenizer options optimised for topic modeling:
        # aggressive cleanup for bag-of-words input.
        TOKENIZER_OPTIONS = {
          language: "en",
          remove_urls: true,
          hashtags: :remove,
          mentions: :remove,
          clean: true,
          punctuation: :none,
          numbers: :none,
          downcase: true,
          stem: :porter,
          remove_stop_words: true,
          min_length: 3,
        }.freeze

        # @param k [Integer, nil] number of topics for LDA; nil → HDP
        # @param min_cf [Integer] minimum corpus frequency for a word to be
        #   included in the vocabulary (filters very rare words)
        # @param rm_top [Integer] number of top-frequency words to remove
        #   before training (generic words like "system", "model")
        # @param iterations [Integer] number of training iterations
        # @param seed [Integer] random seed for reproducibility
        # @param burn_in [Integer, nil] initial training iterations whose
        #   stats are discarded before topic estimates are counted. Matters
        #   most for HDP (k: nil), where the live topic count itself is
        #   still converging during early iterations; nil leaves Tomoto's
        #   own default (0) in place.
        def initialize(k: nil, min_cf: 3, rm_top: 2, iterations: 100, seed: 42, burn_in: nil)
          @k = k
          @min_cf = min_cf
          @rm_top = rm_top
          @iterations = iterations
          @burn_in = burn_in
          @seed = seed
          @model = nil
          @topic_labels = {}
          @fitted = false
        end

        # Pre-pass fit: trains directly on raw text, with no ConversationTurn
        # struct required. Lets callers assign a stable topic id/label to
        # each document *before* clause compilation/storage even runs,
        # instead of the turn-bound #fit below (which needs turns to exist
        # first and is used for the report-level topic_evolution/shifts).
        #
        # @param texts [Array<String>]
        # @return [Array<Integer, nil>] dominant topic id per text, parallel
        #   to +texts+ (nil for texts that tokenize to nothing)
        def fit_texts(texts)
          @model = build_model
          docs = texts.map { |t| tokenize(t) }
          docs.each { |tokens| @model.add_doc(tokens) unless tokens.empty? }

          train_model
          build_topic_labels

          docs.map { |tokens| dominant_topic_for(tokens) }
        end

        private def dominant_topic_for(tokens)
          return nil if tokens.empty?

          doc = @model.make_doc(tokens)
          topic_dist, = @model.infer(doc)
          # A degenerate fit (e.g. no word in the corpus clears min_cf, the
          # "No valid vocabs in the model!" case) infers NaN for every
          # topic — max_by's Float#<=> comparison raises on NaN rather
          # than just losing the comparison, so guard explicitly.
          return nil if topic_dist.any?(&:nan?)

          topic_dist.each_with_index.max_by { |prob, _idx| prob }&.last
        end

        # Train the topic model on an array of ConversationTurn structs.
        #
        # @param turns [Array<Types::ConversationTurn>]
        # @return [self]
        def fit(turns)
          @turns = turns
          docs = turns.map { |t| tokenize(t.message_text) }

          @model = build_model
          docs.each_with_index do |tokens, _idx|
            next if tokens.empty?

            @model.add_doc(tokens)
          end

          train_model
          build_topic_labels
          assign_topics_to_turns
          assign_coherence_scores_to_turns

          @fitted = true
          self
        end

        # Topic labels: top words per topic.
        # @return [Hash{Integer => Array<String>}] topic_id → top words
        attr_reader :topic_labels

        # The processed turns with topic assignment and coherence scores.
        # @return [Array<Types::ConversationTurn>]
        attr_reader :turns

        # Per-turn topic distribution.
        # @return [Array<Hash{Integer => Float}>] array of { topic_id => probability }
        def turn_distributions
          return [] unless @fitted

          @turns.map { |t| t.topic_distribution || {} }
        end

        # Detect significant topic shifts between consecutive turns.
        # A "shift" occurs when the dominant topic changes AND the
        # cosine distance between turn distributions exceeds a threshold.
        #
        # @param threshold [Float] minimum cosine distance to flag a shift
        # @return [Array<Hash>] topic shift events
        def detect_topic_shifts(threshold: 0.3)
          return [] unless @fitted

          shifts = []
          @turns.each_cons(2) do |prev, curr|
            prev_dist = prev.topic_distribution || {}
            curr_dist = curr.topic_distribution || {}
            prev_dominant = prev.dominant_topic
            curr_dominant = curr.dominant_topic

            next if prev_dominant == curr_dominant

            distance = cosine_distance(prev_dist, curr_dist)
            next if distance < threshold

            shifts << {
              turn_id: curr.turn_id,
              type: "topic_shift",
              from_topic: prev_dominant,
              to_topic: curr_dominant,
              magnitude: distance.round(4),
              description: "Topic shifted from #{topic_name(prev_dominant)} " \
                "to #{topic_name(curr_dominant)} (distance: #{distance.round(3)})",
            }
          end
          shifts
        end

        # Save the trained model to disk.
        # @param path [String]
        def save(path)
          raise TopicModelerError, "No model to save — call fit first" unless @model

          @model.save(path)
        end

        # Load a pre-trained model from disk.
        # @param path [String]
        def load_model(path)
          @model = Tomoto::LDA.load(path)
          build_topic_labels
          @fitted = true
          self
        end

        # Calculates semantic coherence score (cosine similarity) between a turn's
        # topic distribution and a baseline distribution.
        #
        # @param turn_dist [Hash{Integer => Float}, nil]
        # @param baseline_dist [Hash{Integer => Float}, nil]
        # @return [Float, nil]
        def calculate_coherence(turn_dist, baseline_dist)
          return nil unless @fitted
          return nil if turn_dist.nil? || baseline_dist.nil?
          return nil if turn_dist.empty? || baseline_dist.empty?

          distance = cosine_distance(turn_dist, baseline_dist)
          similarity = 1.0 - distance
          similarity.clamp(0.0, 1.0).round(4)
        end

        # Compute the average topic distribution of all turns.
        # @return [Hash{Integer => Float}]
        def conversation_baseline
          return {} unless @fitted && @turns && !@turns.empty?

          sum = Hash.new(0.0)
          count = 0

          @turns.each do |turn|
            dist = turn.topic_distribution
            next if dist.nil? || dist.empty?

            dist.each do |topic_id, prob|
              sum[topic_id] += prob
            end
            count += 1
          end

          return {} if count.zero?

          sum.transform_values { |v| (v / count).round(4) }
        end

        private def assign_coherence_scores_to_turns
          # We temporarily mark @fitted to true during calculation
          was_fitted = @fitted
          @fitted = true
          begin
            baseline_dist = conversation_baseline
            @turns = @turns.each_with_index.map do |turn, idx|
              score = nil
              # Gracefully degrade: nil if less than 2 preceding turns (idx < 2)
              # or if the model wasn't fit properly
              if idx >= 2 && !baseline_dist.empty? && turn.topic_distribution && !turn.topic_distribution.empty?
                score = calculate_coherence(turn.topic_distribution, baseline_dist)
              end

              turn.new(semantic_coherence_score: score)
            end
          ensure
            @fitted = was_fitted
          end
        end

        private def build_model
          model = if @k
            Tomoto::LDA.new(
              k: @k,
              min_cf: @min_cf,
              rm_top: @rm_top,
              seed: @seed
            )
          else
            Tomoto::HDP.new(
              min_cf: @min_cf,
              rm_top: @rm_top,
              seed: @seed
            )
          end

          model.burn_in = @burn_in if @burn_in
          model
        end

        private def train_model
          @iterations.times { |_i| @model.train(1) }
        end

        private def build_topic_labels
          num_topics = @model.k
          @topic_labels = {}

          num_topics.times do |topic_id|
            words = @model.topic_words(topic_id)
            @topic_labels[topic_id] = words.map(&:first)
          end
        end

        private def assign_topics_to_turns
          @turns = @turns.map do |turn|
            tokens = tokenize(turn.message_text)

            if tokens.empty?
              turn.new(topic_distribution: {}, dominant_topic: 0)
            else
              doc = @model.make_doc(tokens)
              topic_dist, = @model.infer(doc)

              distribution = {}
              topic_dist.each_with_index do |prob, idx|
                distribution[idx] = prob.round(4) if prob > 0.01
              end

              dominant = distribution.max_by { |_, v| v }&.first || 0

              turn.new(
                topic_distribution: distribution,
                dominant_topic: dominant
              )
            end
          end
        end

        # Tokenize text using PragmaticTokenizer with topic-modeling options.
        # Returns an array of stemmed, lowercased, stopword-free tokens.
        private def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          PragmaticTokenizer::Tokenizer.new(TOKENIZER_OPTIONS).tokenize(text)
        end

        # Simple cosine distance between two topic distributions.
        private def cosine_distance(dist_a, dist_b)
          keys = (dist_a.keys | dist_b.keys)
          return 1.0 if keys.empty?

          dot = keys.sum { |k| (dist_a[k] || 0.0) * (dist_b[k] || 0.0) }
          mag_a = Math.sqrt(dist_a.values.sum { |v| v ** 2 })
          mag_b = Math.sqrt(dist_b.values.sum { |v| v ** 2 })

          return 1.0 if mag_a.zero? || mag_b.zero?

          (1.0 - (dot / (mag_a * mag_b))).round(4)
        end

        private def topic_name(topic_id)
          words = @topic_labels[topic_id] || []
          words.empty? ? "topic #{topic_id}" : words.first(3).join("/")
        end
      end
    end
  end
end
