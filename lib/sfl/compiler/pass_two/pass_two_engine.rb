# frozen_string_literal: true

require "dspy"
require "dry/monads"
require "journald/logger"

module SFL
  module Compiler
    # Pass Two: Semantic Annotation Engine
    #
    # Uses DSPy.rb to map syntactic structures onto SFL metafunctions.
    # Each DSPy::Signature defines a typed contract for LLM-based
    # annotation of a specific SFL dimension.
    #
    # DSPy configuration must be set externally before calling
    # `DSPy.configure { |c| c.lm = ... }`.
    class PassTwoEngine
      include Dry::Monads[:result]

      def initialize(provider: nil, circuit_breaker: nil)
        @provider = provider || SFL::Compiler.config.dspy_provider
        @circuit_breaker = circuit_breaker || default_circuit_breaker
        @logger = Journald::Logger.new("sfl-compiler-pass-two")
      end

      # Annotate a clause with SFL metafunctions.
      #
      # @param clause [Types::SyntacticClause] from Pass 1
      # @param ideational [Types::IdeationalPayload] from Pass 1 post-processing
      # @return [Types::AnnotatedClause]
      def annotate(clause, ideational)
        start_time = Time.now
        correlation_id = SecureRandom.uuid

        @logger.send_message(
          message: "pass_two_started",
          priority: Journald::LOG_INFO,
          correlation_id: correlation_id,
          clause_id: clause.id,
          text_length: clause.text.length
        )

        # Run DSPy annotation for Interpersonal features
        interpersonal = annotate_interpersonal(clause, ideational, correlation_id)

        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "pass_two_completed",
          priority: Journald::LOG_INFO,
          correlation_id: correlation_id,
          clause_id: clause.id,
          modality_weight: interpersonal.modality_weight,
          tenor: interpersonal.tenor,
          mood: interpersonal.mood,
          latency_ms: elapsed_ms
        )

        Types::AnnotatedClause.new(
          id: SecureRandom.uuid,
          text: clause.text,
          syntactic: clause,
          ideational: ideational,
          interpersonal: interpersonal,
          document_id: clause.document_id,
          compiled_at: Time.now
        )
      rescue StandardError => e
        elapsed_ms = ((Time.now - start_time) * 1000).round(2)

        @logger.send_message(
          message: "pass_two_failed",
          priority: Journald::LOG_ERR,
          correlation_id: correlation_id,
          clause_id: clause.id,
          error_class: e.class.name,
          error_message: e.message,
          latency_ms: elapsed_ms
        )

        raise PassTwoError, "Semantic annotation failed: #{e.message}"
      end

      private

      # Returns a transparent callable that simply yields the block.
      # TODO: replace with a proper CircuitBreaker::CircuitHandler once
      #       Pass 2 is in active use and failure rates are monitored.
      # The rescue on CircuitBreaker::OpenError in annotate_interpersonal
      # handles the tripped case when a real handler is substituted in.
      def default_circuit_breaker
        lambda { |&block| block.call }
      end

      def annotate_interpersonal(clause, ideational, correlation_id)
        # Build the syntactic context for the LLM
        syntactic_context = format_syntactic_context(clause, ideational)

        # Call DSPy through circuit breaker for resilience
        result = @circuit_breaker.call do
          sfl_annotator = SFLAnnotator.new(syntactic_context)
          sfl_annotator.call
        end

        Types::InterpersonalPayload.new(
          clause_id: clause.id,
          mood: result[:mood] || "declarative",
          modality_weight: result[:modality_weight] || 0.5,
          tenor: result[:tenor] || 0.5,
          speaker_attitude: result[:speaker_attitude],
          reasoning: result[:reasoning]
        )
      rescue CircuitBreaker::CircuitBrokenException
        @logger.send_message(
          message: "pass_two_circuit_open",
          priority: Journald::LOG_WARNING,
          correlation_id: correlation_id,
          clause_id: clause.id
        )
        # Graceful degradation: return default interpersonal values
        default_interpersonal(clause.id)
      end

      def format_syntactic_context(clause, ideational)
        <<~CONTEXT
          Text: #{clause.text}

          Root verb: #{root_info(clause)}
          Process type: #{ideational.process_type}
          Participants: #{ideational.participants.join(", ")}
          POS tags: #{pos_sequence(clause)}
          Dependencies: #{dep_sequence(clause)}
        CONTEXT
      end

      def root_info(clause)
        root = clause.tokens[clause.root_index]
        return "unknown" if root.nil?

        "#{root.text} (lemma: #{root.lemma}, pos: #{root.pos}, tag: #{root.tag})"
      end

      def pos_sequence(clause)
        clause.tokens.map { |t| "#{t.text}/#{t.pos}" }.join(" ")
      end

      def dep_sequence(clause)
        clause.tokens.map { |t| "#{t.text}<#{t.dep}" }.join(" ")
      end

      def default_interpersonal(clause_id)
        Types::InterpersonalPayload.new(
          clause_id: clause_id,
          mood: "declarative",
          modality_weight: 0.5,
          tenor: 0.5,
          speaker_attitude: nil,
          reasoning: "Circuit breaker open — defaults applied"
        )
      end
    end

    # DSPy.rb signature for SFL interpersonal annotation.
    # Defines the typed contract for LLM-based mood, modality,
    # and tenor classification.
    class SFLSignature < DSPy::Signature
      description "Analyze the interpersonal metafunction of a clause using " \
                  "Systemic Functional Linguistics (SFL). Determine mood type, " \
                  "modality weight (certainty of the claim), and tenor " \
                  "(formality level). Base your analysis on the syntactic " \
                  "structure provided."

      input do
        const :text, String, description: "The raw clause text"
        const :root_verb, String, description: "The root verb with POS and lemma"
        const :process_type, String, description: "Ideational process type from Pass 1"
        const :participants, String, description: "Semantic roles of participants"
        const :pos_tags, String, description: "POS tag sequence"
        const :dependencies, String, description: "Dependency relation sequence"
      end

      output do
        const :mood, String, description: "Clause mood: declarative, interrogative, imperative, or exclamative"
        const :modality_weight, Float, description: "Modality strength 0.0-1.0 (0=weak/hedged, 1=strong/certain)"
        const :tenor, Float, description: "Formality level 0.0-1.0 (0=informal, 1=formal)"
        const :speaker_attitude, String, description: "Speaker attitude: neutral, positive, negative, skeptical, assertive"
        const :reasoning, String, description: "Step-by-step reasoning for the classification"
      end
    end

    # DSPy annotator module using ChainOfThought for reasoning.
    class SFLAnnotator
      def initialize(syntactic_context)
        @context = syntactic_context
      end

      def call
        # Parse the formatted context back into DSPy signature inputs
        inputs = parse_context(@context)

        predictor = DSPy::ChainOfThought.new(SFLSignature)
        result = predictor.call(**inputs)

        {
          mood: result.mood,
          modality_weight: result.modality_weight,
          tenor: result.tenor,
          speaker_attitude: result.speaker_attitude,
          reasoning: result.reasoning
        }
      rescue StandardError => e
        SFL::Compiler.logger.send_message(
          message: "sfl_annotator_failed",
          priority: Journald::LOG_WARNING,
          error: e.message
        )
        {
          mood: "declarative",
          modality_weight: 0.5,
          tenor: 0.5,
          speaker_attitude: "neutral",
          reasoning: "DSPy annotation failed: #{e.message}"
        }
      end

      private

      def parse_context(context)
        lines = context.strip.split("\n")
        lines = lines.map { |l| l.split(":", 2) }

        text = extract_field(lines, "Text") || ""
        root_verb = extract_field(lines, "Root verb") || "unknown"
        process_type = extract_field(lines, "Process type") || "material"
        participants = extract_field(lines, "Participants") || ""
        pos_tags = extract_field(lines, "POS tags") || ""
        dependencies = extract_field(lines, "Dependencies") || ""

        {
          text: text,
          root_verb: root_verb,
          process_type: process_type,
          participants: participants,
          pos_tags: pos_tags,
          dependencies: dependencies
        }
      end

      def extract_field(lines, key)
        line = lines.find { |l| l[0]&.strip == key }
        line&.[](1)&.strip
      end
    end
  end
end
