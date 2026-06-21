# frozen_string_literal: true

require "circuit_breaker"
require "journald/logger"
require "ruby_llm"

module SFL
  module Compiler
    # Simple embedding interface compatible with HybridRetriever.
    # Uses Ollama for embedding generation via ruby_llm.
    class Embedder
      include CircuitBreaker

      def initialize(model: "embeddinggemma:latest", ollama_base_url: nil)
        @model = model
        @logger = Journald::Logger.new("sfl-compiler-embedder")
        configure_ruby_llm(ollama_base_url)
      end

      # Generate embedding vector for text.
      #
      # @param text [String]
      # @return [Array<Float>, nil]
      def embed(text)
        return nil if text.nil? || text.strip.empty?

        call_ruby_llm(text)
      rescue CircuitBreaker::CircuitBrokenException
        @logger.send_message(
          message: "embedder_circuit_open",
          priority: Journald::LOG_WARNING
        )
        nil
      rescue => e
        @logger.send_message(
          message: "embed_failed",
          priority: Journald::LOG_ERR,
          error: e.message
        )
        nil
      end

      private def configure_ruby_llm(ollama_base_url)
        ollama_base_url ||= ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434")
        RubyLLM.configure do |config|
          config.ollama_api_base = openai_compatible_base(ollama_base_url)
          config.default_embedding_model = @model
        end
      end

      # RubyLLM::Providers::Ollama subclasses the OpenAI provider and only
      # speaks OpenAI-style routes, so the base URL needs the /v1 suffix
      # (see ruby_llm's "Ollama" config example). Without it, requests land
      # on bare /embeddings instead of /v1/embeddings, which Ollama doesn't route.
      private def openai_compatible_base(base_url)
        base = base_url.chomp("/")
        base.end_with?("/v1") ? base : "#{base}/v1"
      end

      private def call_ruby_llm(text)
        response = RubyLLM.embed(text, model: @model, provider: :ollama)
        response.vectors
      end
      circuit_method :call_ruby_llm

      circuit_handler do |handler|
        handler.failure_threshold = 5
        handler.failure_timeout = 60
        handler.invocation_timeout = 30
      end
    end
  end
end
