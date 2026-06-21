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
        def initialize(k: nil, min_cf: 3, rm_top: 2, iterations: 100, seed: 42)
          @k = k
          @min_cf = min_cf
          @rm_top = rm_top
          @iterations = iterations
          @seed = seed
          @model = nil
          @topic_labels = {}
          @fitted = false
        end

        # Train the topic model on an array of ConversationTurn structs.
        #
        # @param turns [Array<Types::ConversationTurn>]
        # @return [self]
        def fit(turns)
          @turns = turns
          docs = turns.map { |t| tokenize(t.message_text) }

          @model = build_model
          docs.each { |tokens| @model.add_doc(tokens) }

          train_model
          build_topic_labels
          assign_topics_to_turns

          @fitted = true
          self
        end

        # Topic labels: top words per topic.
        # @return [Hash{Integer => Array<String>}] topic_id → top words
        attr_reader :topic_labels

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

        private def build_model
          if @k
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
