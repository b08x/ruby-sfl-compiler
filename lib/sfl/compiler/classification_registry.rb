# frozen_string_literal: true

require "amatch"

module SFL
  module Compiler
    # Centralized registry for mood and theme_type classifications.
    # Eliminates redundancy across types, normalizers, and wizard prompt configs.
    module ClassificationRegistry
      # Fuzzy-match floor for the Jaro-Winkler fallback in .normalize.
      # Calibrated against live Pass 2 output: every observed real
      # near-miss scores >= 0.9378 against its intended target
      # ("subjective"→"subjunctive" 0.944, "imperitive"→"imperative"
      # 0.938, "interogative"→"interrogative" 0.985), while the best
      # garbage/unrelated term tops out at 0.809 ("performative"→
      # "imperative"; "infinitive"→"indicative" 0.802). 0.92 sits in
      # that gap with margin on both sides — raise it before ever
      # lowering it, since a false fuzzy match silently rewrites a
      # value while a miss merely falls through to the (warned)
      # default.
      FUZZY_THRESHOLD = 0.92

      # Below this length Jaro-Winkler scores inflate (and the prefix
      # bonus dominates), so short unknowns fall straight through to
      # the default rather than risking a spurious match.
      FUZZY_MIN_LENGTH = 4
      MOOD = {
        canonical: %w[declarative interrogative imperative exclamative indicative minor fragment].freeze,
        aliases: {
          "exclamatory" => "exclamative",
          "non-finite" => "fragment",
          "none" => "fragment",
          "vocative" => "minor",
          "question" => "interrogative",
          "questions" => "interrogative",
          "query" => "interrogative",
          "queries" => "interrogative",
          "elliptical" => "declarative",
          "elliptical_fragment" => "fragment",
          "nominal" => "fragment",
          "narrative" => "declarative",
          "continuative" => "declarative",
          "rhetorical_question" => "interrogative",
          "rhetorical question" => "interrogative",
          # LLM modality/mood conflation — "modal" describes a feature, not a mood
          "modal" => "declarative",
          # Hortatory/urging clauses — directive like imperative in SFL
          "exhortative" => "imperative",
          # Conditional and subjunctive are not primary SFL mood categories
          "conditional" => "declarative",
          "subjunctive" => "declarative",
          "subjective" => "declarative", # LLM near-miss for "subjunctive"
          # Interjections lack full Mood/Residue structure — SFL treats them
          # as "minor" clauses (calls, greetings, exclamations of alarm),
          # not a mood category of their own. Observed on emotionally
          # charged stream-of-consciousness prose (a personal essay
          # containing "Oh good", "Oh my god"-style interjections).
          "interjectional" => "minor",
          "interjection" => "minor",
          # No-value sentinels the LLM returns when it cannot determine mood
          # ("neutral" observed 6x in one live KB run over Daily notes —
          # the model saying "no marked mood", which in SFL is the
          # unmarked declarative)
          "neutral" => "declarative",
          "null" => "declarative",
          "n/a" => "declarative",
          "" => "declarative",
        }.freeze,
        transforms: [
          -> (val) { val.end_with?("_phrase") ? "fragment" : val },
          # Strips a trailing parenthetical qualifier (e.g. "declarative
          # (elliptical)" -> "declarative") so the bare mood term underneath
          # still resolves to a canonical/aliased value instead of falling
          # through to :unknown.
          -> (val) { val.sub(/\s*\(.*\)\z/, "") },
        ].freeze,
        default: "declarative",
      }.freeze

      THEME_TYPE = {
        canonical: %w[
          unmarked
          marked
          interrogative
          imperative
          multiple
          topical
          simple
          existential
          clausal
          textual
          interjection
          interpersonal
          predicated
          predicator
          circumstantial
        ].freeze,
        aliases: {
          "topual" => "topical",
          "topical_unmarked" => "topical",
          "vocative" => "interpersonal",
          "process" => "predicator",
          "modal" => "interpersonal",
          "interjectional" => "interjection",
          # Circumstantial theme sub-types — a circumstantial adjunct
          # (time, place, manner, cause) occupying thematic position.
          # e.g. "On Monday, the system crashed." All map to circumstantial.
          "temporal" => "circumstantial",
          "spatial" => "circumstantial",
          "causal" => "circumstantial",
          "conditional" => "circumstantial",
          "concessive" => "circumstantial",
          "manner" => "circumstantial",
          # "marking" → model intended "marked theme"
          "marking" => "marked",
          # No-value sentinels the LLM returns when it cannot determine theme type
          "null" => "unmarked",
          "none" => "unmarked",
          "n/a" => "unmarked",
          "" => "unmarked",
        }.freeze,
        transforms: [
          lambda do |val|
            val = val.split("+").map(&:strip).find { |p| !p.empty? } || "" if val.include?("+")
            val = val.delete_prefix("theme_").delete_suffix("_theme").delete_suffix(" theme").strip
            # Check for multiple theme components separated by >, ,, _, or the
            # natural-language conjunction "and" (e.g. an LLM writing
            # "topical and interpersonal" instead of "topical, interpersonal")
            # (excluding known single terms like topical_unmarked)
            if val.include?(">") || val.include?(",") || val.match?(/\band\b/) ||
                (val.include?("_") && val != "topical_unmarked")

              parts = val.split(/[>,_]|\s+and\s+/).map(&:strip).reject(&:empty?)
              val = "multiple" if parts.size > 1
            end
            val
          end,
        ].freeze,
        default: "unmarked",
      }.freeze

      # Precomputed fuzzy-match candidate pools (canonical values plus
      # alias keys, minus entries too short to match reliably) — frozen
      # constants rather than a lazily-built cache because normalize runs
      # per-clause on PassTwoEngine's multi-threaded pool.
      FUZZY_CANDIDATES = {
        mood: (MOOD[:canonical] + MOOD[:aliases].keys)
          .reject { |c| c.length < FUZZY_MIN_LENGTH }.freeze,
        theme_type: (THEME_TYPE[:canonical] + THEME_TYPE[:aliases].keys)
          .reject { |c| c.length < FUZZY_MIN_LENGTH }.freeze,
      }.freeze

      # Normalizes a raw classification string to a canonical value.
      # Returns [canonical_value, status] where status is :exact,
      # :aliased, :fuzzy, or :unknown.
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def self.normalize(dimension, raw)
        config = dimension_config(dimension)
        val = raw.to_s.downcase.strip

        config[:transforms].each do |transform|
          val = transform.call(val)
          val = val.to_s.strip
        end

        if config[:canonical].include?(val)
          [val, :exact]
        elsif config[:aliases].key?(val)
          [config[:aliases][val], :aliased]
        elsif (fuzzy = fuzzy_lookup(dimension, config, val))
          [fuzzy, :fuzzy]
        else
          [config[:default], :unknown]
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # Last resort before defaulting: Jaro-Winkler the unknown value
      # against every canonical value and alias key, resolving through
      # the alias table when the best hit is an alias. Catches the
      # long tail of LLM near-misses (typos, adjectival forms, plural
      # "s") that previously each needed a hand-written alias entry
      # after showing up in a live run's WARNs.
      private_class_method def self.fuzzy_lookup(dimension, config, val)
        return nil if val.length < FUZZY_MIN_LENGTH

        matcher = Amatch::JaroWinkler.new(val)
        best, score = FUZZY_CANDIDATES[dimension.to_sym].map { |c| [c, matcher.match(c)] }.max_by(&:last)
        return nil if score < FUZZY_THRESHOLD

        # Alias keys never overlap canonical values (aliases map INTO the
        # canonical set), so a canonical hit falls through fetch's default.
        config[:aliases].fetch(best, best)
      end

      # Returns a duplicate array of the canonical values.
      def self.canonical_values(dimension)
        dimension_config(dimension)[:canonical].dup
      end

      # Returns a formatted list suitable for DSPy signature descriptions.
      def self.signature_description(dimension)
        vals = dimension_config(dimension)[:canonical]
        if vals.empty?
          ""
        elsif vals.size == 1
          vals.first
        else
          "#{vals[0...-1].join(', ')}, or #{vals.last}"
        end
      end

      private_class_method def self.dimension_config(dimension)
        case dimension.to_sym
        when :mood
          MOOD
        when :theme_type
          THEME_TYPE
        else
          raise ArgumentError, "Unknown dimension: #{dimension}"
        end
      end
    end
  end
end
