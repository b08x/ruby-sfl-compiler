# frozen_string_literal: true

require "dry-struct"
require "dry-types"
require "dry/monads"
require "securerandom"

module SFL
  module Compiler
    module Types
      include Dry.Types()

      # SFL Metafunction categories
      MetafunctionType = String.enum("ideational", "interpersonal", "textual")

      # Interpersonal scalar types
      ModalityWeight = Types::Float.constrained(gteq: 0.0, lteq: 1.0)
      TenorValue = Types::Float.constrained(gteq: 0.0, lteq: 1.0)

      # Mood types from SFL
      MoodType = String.enum("declarative", "interrogative", "imperative", "exclamative", "indicative", "minor", "fragment")

      # Provenance of interpersonal values: "llm" = real Pass 2 annotation,
      # "fallback" = Pass 2 failed and defaults were substituted,
      # "stub" = Pass 2 was skipped entirely (e.g. PASS=1 runs)
      AnnotationSource = String.default("llm").enum("llm", "fallback", "stub")

      # Transitivity process types (Ideational)
      ProcessType = String.enum("material", "mental", "relational", "verbal", "behavioral", "existential")

      # Participant in a process
      class Participant < Dry::Struct
        attribute :role, Types::String
        attribute :text, Types::String
      end

      # Represents a single token with syntactic annotations from Pass 1
      class SyntacticToken < Dry::Struct
        attribute :text, Types::String
        attribute :lemma, Types::String
        attribute :pos, Types::String          # Coarse POS (e.g., "VERB", "NOUN")
        attribute :tag, Types::String          # Fine-grained POS (e.g., "VBG", "NNP")
        attribute :dep, Types::String          # Dependency relation (e.g., "nsubj", "ROOT")
        attribute :head_index, Types::Integer  # Index of head token (-1 for ROOT)
        attribute :morphology, Types::Hash.default({}.freeze)
        attribute :index, Types::Integer       # Position in sentence
      end

      # A clause with full syntactic tree from Pass 1
      class SyntacticClause < Dry::Struct
        attribute :id, Types::String.default { SecureRandom.uuid }
        attribute :text, Types::String
        attribute :tokens, Types::Array.of(SyntacticToken)
        attribute :root_index, Types::Integer
        attribute :sentence_index, Types::Integer
        attribute :document_id, Types::String.optional
      end

      # Ideational metafunction payload (from Pass 1)
      class IdeationalPayload < Dry::Struct
        attribute :clause_id, Types::String
        attribute :process_type, Types::ProcessType
        attribute :participants, Types::Array.of(Participant)  # Semantic roles
        attribute :circumstances, Types::Array.of(Types::String)  # Adjuncts
        attribute :raw_transitivity, Types::Hash                  # Full transitivity parse
      end

      # Interpersonal metafunction payload (from Pass 2)
      class InterpersonalPayload < Dry::Struct
        attribute :clause_id, Types::String
        attribute :mood, Types::MoodType
        attribute :modality_weight, Types::ModalityWeight
        attribute :tenor, Types::TenorValue
        attribute :speaker_attitude, Types::String.optional
        attribute :reasoning, Types::String.optional  # DSPy ChainOfThought reasoning
        attribute :annotation_source, Types::AnnotationSource
      end

      # Textual metafunction payload (from Pass 2)
      class TextualPayload < Dry::Struct
        attribute :clause_id, Types::String
        attribute :topical_theme, Types::String.optional
        attribute :textual_theme, Types::String.optional
        attribute :interpersonal_theme, Types::String.optional
        attribute :rheme, Types::String.optional
        attribute :theme_type, Types::String.enum("unmarked", "marked", "interrogative", "imperative", "multiple", "topical", "topical_unmarked", "simple", "existential", "clausal", "textual", "interjection", "interpersonal").optional
      end

      # Combined annotated clause — the full output of the two-pass compiler
      class AnnotatedClause < Dry::Struct
        attribute :id, Types::String
        attribute :text, Types::String
        attribute :syntactic, SyntacticClause
        attribute :ideational, IdeationalPayload
        attribute :interpersonal, InterpersonalPayload
        attribute :textual, TextualPayload.optional.default(nil)
        attribute :document_id, Types::String.optional
        attribute :compiled_at, Types::Time
      end

      # Cohesion metrics for a group of clauses
      class CohesionMetrics < Dry::Struct
        attribute :repetition_score, Types::Float.constrained(gteq: 0.0, lteq: 1.0).default(0.0)
        attribute :conjunction_density, Types::Float.constrained(gteq: 0.0, lteq: 1.0).default(0.0)
        attribute :pronoun_density, Types::Float.constrained(gteq: 0.0, lteq: 1.0).default(0.0)
      end

      # Dispatch decision for the orchestrator
      class DispatchDecision < Dry::Struct
        attribute :mode, Types::String.enum("lite", "standard")
        attribute :spacy_model, Types::String.default("en_core_web_sm")
        attribute :dspy_provider, Types::String.default("openai/gpt-4o-mini")
        attribute :dspy_api_key_env, Types::String.default("OPENAI_API_KEY")
        attribute :strategy, Types::String.enum("sequential", "parallel")
        attribute :quality_gate, Types::String.enum("sift", "do_and_judge", "none")
        attribute :correlation_id, Types::String.default { SecureRandom.uuid }
      end

      # Task result from sub-agent execution
      class TaskResult < Dry::Struct
        attribute :agent, Types::String.enum("pass_one", "pass_two", "orchestrator", "context")
        attribute :success, Types::Bool
        attribute :output, Types::Hash.default({}.freeze)
        attribute :error, Types::String.optional
        attribute :duration_ms, Types::Float
        attribute :correlation_id, Types::String
        attribute :timestamp, Types::Time
      end

      # Conversation analysis data structures

      # A single turn in a conversation with SFL annotations
      class ConversationTurn < Dry::Struct
        attribute :turn_id, Types::Integer
        attribute :speaker, Types::String
        attribute :timestamp, Types::Time
        attribute :message_text, Types::String
        attribute :clauses, Types::Array.of(AnnotatedClause)
        attribute :avg_tenor, Types::Float.constrained(gteq: 0.0, lteq: 1.0)
        attribute :avg_modality, Types::Float.constrained(gteq: 0.0, lteq: 1.0)
        attribute :dominant_mood, Types::MoodType
        attribute :process_types, Types::Hash.default({}.freeze)
        attribute :participants, Types::Array.of(Types::String).default([].freeze)
        attribute :tenor_shift, Types::Float.optional
        attribute :cohesion, CohesionMetrics.optional.default(nil)
        attribute :topic_distribution, Types::Hash.optional.default(nil)
        attribute :dominant_topic, Types::Integer.optional.default(nil)
      end

      # Aggregated profile for a single speaker across conversation
      class SpeakerProfile < Dry::Struct
        attribute :speaker_name, Types::String
        attribute :turn_count, Types::Integer
        attribute :avg_tenor, Types::Float.constrained(gteq: 0.0, lteq: 1.0)
        attribute :tenor_range, Types::Array.of(Types::Float).constrained(size: 2)
        attribute :tenor_variance, Types::Float.constrained(gteq: 0.0)
        attribute :avg_modality, Types::Float.constrained(gteq: 0.0, lteq: 1.0)
        attribute :mood_distribution, Types::Hash.default({}.freeze)
        attribute :dominant_processes, Types::Hash.default({}.freeze)
      end

      # Key moments in a conversation
      class KeyMoment < Dry::Struct
        attribute :turn_id, Types::Integer
        attribute :type, Types::String.enum("tenor_shift", "modality_shift", "topic_shift")
        attribute :magnitude, Types::Float
        attribute :description, Types::String
      end

      # Example passages for a specific rhetorical stance
      class ExamplePassage < Dry::Struct
        attribute :label, Types::String
        attribute :text, Types::String
        attribute :speaker, Types::String
        attribute :value, Types::Float
        attribute :reason, Types::String
      end

      # Complete analysis result for a conversation
      class AnalysisResult < Dry::Struct
        attribute :metadata, Types::Hash
        attribute :turns, Types::Array.of(ConversationTurn)
        attribute :speaker_profiles, Types::Hash
        attribute :tenor_timeline, Types::Array.of(Types::Hash)
        attribute :field_evolution, Types::Array.of(Types::Hash)
        attribute :correlations, Types::Hash
        attribute :insights, Types::Array.of(Types::String)
        attribute :key_moments, Types::Array.of(KeyMoment).default([].freeze)
        attribute :example_passages, Types::Array.of(ExamplePassage).default([].freeze)
        attribute :topic_labels, Types::Hash.optional.default(nil)
        attribute :topic_evolution, Types::Array.of(Types::Hash).default([].freeze)
      end

      # Result of a context query: hybrid retrieval + LLM synthesis
      class SynthesisResult < Dry::Struct
        attribute :query, Types::String
        attribute :answer, Types::String.optional
        attribute :cited_clause_ids, Types::Array.of(Types::String).default([].freeze)
        attribute :clauses, Types::Array.of(Types::Hash).default([].freeze)
        attribute :retrieved_count, Types::Integer
        attribute :confidence, Types::Float.optional
      end

      # An LLM-written interpretive narrative over an analysis. Six fixed
      # prose sections; assembly into markdown is the formatter's job.
      class NarrativeReport < Dry::Struct
        attribute :source, Types::String
        attribute :generated_at, Types::Time
        attribute :overview, Types::String
        attribute :cast_and_roles, Types::String
        attribute :interpersonal_dynamics, Types::String
        attribute :conversational_arc, Types::String
        attribute :data_quality, Types::String
        attribute :takeaways, Types::String
      end
    end
  end
end
