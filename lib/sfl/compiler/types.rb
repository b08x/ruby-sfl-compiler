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
      MoodType = String.enum("declarative", "interrogative", "imperative", "exclamative")

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
      end

      # Combined annotated clause — the full output of the two-pass compiler
      class AnnotatedClause < Dry::Struct
        attribute :id, Types::String
        attribute :text, Types::String
        attribute :syntactic, SyntacticClause
        attribute :ideational, IdeationalPayload
        attribute :interpersonal, InterpersonalPayload
        attribute :document_id, Types::String.optional
        attribute :compiled_at, Types::Time
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
    end
  end
end
