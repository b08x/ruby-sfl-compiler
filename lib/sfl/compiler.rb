# frozen_string_literal: true

# Two-Pass SFL Compiler for high-fidelity RAG
#
# Separates syntactic extraction (Pass 1: ruby-spacy) from semantic
# annotation (Pass 2: dspy.rb) to produce multi-layered indexable
# payloads with scalar filtering on interpersonal features.
#
# Architecture:
#   Pass 1: SyntacticEngine -> IdeationalExtractor
#     - Tokenization, POS tagging, dependency parsing via ruby-spacy
#     - Rule-based transitivity classification (process, participants, circumstances)
#
#   Pass 2: SemanticAnnotator (DSPy.rb)
#     - LLM-based mood, modality, tenor classification
#     - Circuit breaker protected for resilience
#
#   Storage: PostgreSQL + pgvector
#     - Separated tables for Ideational and Interpersonal payloads
#     - Scalar indices for filtering on modality_weight, tenor, mood
#     - Vector index for semantic similarity search
#
#   Retrieval: Hybrid RRF
#     - Semantic (vector) + keyword (full-text) with Reciprocal Rank Fusion
#     - Scalar metadata filters on interpersonal features
#
# @example Basic usage
#   require "sfl/compiler"
#
#   SFL::Compiler.configure do |c|
#     c.database_url = "postgresql://localhost:5432/sfl_dev"
#   end
#
#   db = SFL::Compiler::Database.connect
#   pipeline = SFL::Compiler::Pipeline.new(db: db)
#   results = pipeline.compile("Your text here", document_id: "doc-1")
#
# @example Retrieval with scalar filters
#   retriever = SFL::Compiler::HybridRetriever.new(db: db)
#   results = retriever.retrieve(
#     "input validation",
#     filters: { min_modality: 0.7, min_tenor: 0.5 }
#   )
module SFL
  module Compiler
    class Error < StandardError; end
    class PassOneError < Error; end
    class PassTwoError < Error; end
    class ConfigurationError < Error; end
    class BootstrapError < Error; end

    # Raised when narrative generation cannot proceed: the input digest is
    # absent or invalid (e.g. a report JSON without a `turns` array), or the
    # LLM returned output missing required sections.
    class NarrativeError < Error; end

    # Raised when topic modeling encounters unrecoverable errors.
    class TopicModelerError < Error; end

    def self.logger
      require "journald/logger"
      @logger ||= Journald::Logger.new("sfl-compiler")
    end

    def self.config
      @config ||= Configuration.new
    end

    def self.configure
      yield config
    end

    class Configuration
      attr_accessor :database_url, :spacy_model, :dspy_provider,
                    :dspy_api_key_env, :openai_api_key, :log_level,
                    :ollama_base_url, :embedding_model

      def initialize
        @database_url = ENV.fetch("DATABASE_URL", "postgresql:///sfl_compiler_dev")
        @spacy_model = "en_core_web_sm"
        @dspy_provider = "openai/gpt-4o-mini"
        @dspy_api_key_env = "OPENAI_API_KEY"
        @openai_api_key = ENV.fetch("OPENAI_API_KEY", nil)
        @log_level = ENV.fetch("LOG_LEVEL", "info")
        @ollama_base_url = ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434")
        @embedding_model = ENV.fetch("EMBEDDING_MODEL", "embeddinggemma:latest")
      end

      def validate!
        raise ConfigurationError, "DATABASE_URL not set" if database_url.nil? || database_url.empty?
      end
    end
  end
end

require "zeitwerk"

loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path("..", __dir__))
loader.ignore(File.expand_path("../sfl-compiler.rb", __dir__))
loader.ignore(File.expand_path("compiler/version.rb", __dir__))
loader.tag = "sfl-compiler"
loader.inflector.inflect(
  "sfl" => "SFL",
  "cli" => "CLI",
  "tui" => "TUI",
  "rrf" => "RRF",
  "markdown_loader" => "MarkdownLoader"
)
loader.collapse("#{__dir__}/compiler/pass_one")
loader.collapse("#{__dir__}/compiler/pass_two")
loader.collapse("#{__dir__}/compiler/storage")
loader.collapse("#{__dir__}/compiler/retrieval")
loader.collapse("#{__dir__}/compiler/analysis")
loader.collapse("#{__dir__}/compiler/formatters")
loader.collapse("#{__dir__}/compiler/chat")
loader.collapse("#{__dir__}/compiler/tui")
loader.collapse("#{__dir__}/compiler/tui/wizards")
loader.setup
