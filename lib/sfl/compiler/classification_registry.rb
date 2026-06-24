# frozen_string_literal: true

module SFL
  module Compiler
    # Centralized registry for mood and theme_type classifications.
    # Eliminates redundancy across types, normalizers, and wizard prompt configs.
    module ClassificationRegistry
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
          "nominal" => "fragment",
          "narrative" => "declarative",
        }.freeze,
        transforms: [
          -> (val) { val.end_with?("_phrase") ? "fragment" : val },
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
        ].freeze,
        aliases: {
          "topual" => "topical",
          "topical_unmarked" => "topical",
          "vocative" => "interpersonal",
          "process" => "predicator",
          "modal" => "interpersonal",
        }.freeze,
        transforms: [
          lambda do |val|
            val = val.split("+").map(&:strip).find { |p| !p.empty? } || "" if val.include?("+")
            val = val.delete_prefix("theme_").delete_suffix("_theme").delete_suffix(" theme").strip
            # Check for multiple theme components separated by >, ,, or _
            # (excluding known single terms like topical_unmarked)
            if val.include?(">") || val.include?(",") || (val.include?("_") && val != "topical_unmarked")
              parts = val.split(/[>,_]/).map(&:strip).reject(&:empty?)
              val = "multiple" if parts.size > 1
            end
            val
          end,
        ].freeze,
        default: "unmarked",
      }.freeze

      # Normalizes a raw classification string to a canonical value.
      # Returns [canonical_value, status] where status is :exact, :aliased, or :unknown.
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
        else
          [config[:default], :unknown]
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

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
