# frozen_string_literal: true

require "dotenv"
require "dspy"

module SFL
  module Compiler
    # One-stop environment wiring for CLI/TUI entry points: loads .env,
    # propagates env vars into SFL::Compiler.config, configures DSPy's LM,
    # and connects the database. Library analyzers never read ENV — only
    # entry points call Bootstrap.
    module Bootstrap
      Context = Struct.new(:db, :config, keyword_init: true)

      KEY_ENV_BY_PREFIX = {
        "openrouter/" => "OPENROUTER_API_KEY",
        "google/" => "GOOGLE_API_KEY",
        "openai/" => "OPENAI_API_KEY",
        "anthropic/" => "ANTHROPIC_API_KEY"
      }.freeze

      module_function

      # @param require_db [Boolean] connect + migrate the database
      # @param require_llm [Boolean] configure DSPy (false for --pass1-only)
      # @param env [#[]] environment source, injectable for tests
      # @param load_dotenv [Boolean] read .env first (off in tests)
      # @return [Context]
      def call(require_db: true, require_llm: true, env: ENV, load_dotenv: true)
        Dotenv.load if load_dotenv

        config = SFL::Compiler.config
        config.database_url = env["DATABASE_URL"] if env["DATABASE_URL"]
        config.spacy_model = env["SPACY_MODEL"] if env["SPACY_MODEL"]
        config.dspy_provider = env["DSPY_PROVIDER"] if env["DSPY_PROVIDER"]
        config.ollama_base_url = env["OLLAMA_BASE_URL"] if env["OLLAMA_BASE_URL"]
        config.embedding_model = env["EMBEDDING_MODEL"] if env["EMBEDDING_MODEL"]

        configure_llm(config.dspy_provider, env) if require_llm
        db = connect_db(config) if require_db

        Context.new(db: db, config: config)
      end

      DEFAULT_LLM_TIMEOUT = 120.0

      def configure_llm(provider, env)
        key = api_key_for(provider, env)
        lm = DSPy::LM.new(provider, api_key: key, structured_outputs: true)
        apply_request_timeout(lm, key, (env["SFL_LLM_TIMEOUT"] || DEFAULT_LLM_TIMEOUT).to_f)
        DSPy.configure { |c| c.lm = lm }
      end

      # The openai-gem client behind the openai/ and openrouter/ adapters
      # defaults to a 600s request timeout; a connection the server drops
      # mid-request blocks a Pass 2 worker for that long (× retries) with
      # no exception for the engine's fallback ladder to catch. The adapter
      # doesn't expose timeout, so rebuild its client with one.
      #
      # We wrap the client in a SafeOpenAIClientProxy to catch API errors
      # (e.g. rate limits, billing, server errors) that would otherwise
      # result in a confusing NoMethodError (undefined method 'first' for nil)
      # inside the dspy-openai adapter.
      def apply_request_timeout(lm, api_key, timeout_seconds)
        adapter = lm.instance_variable_get(:@adapter)
        client = adapter&.instance_variable_get(:@client)
        return unless defined?(::OpenAI::Client) && client.is_a?(::OpenAI::Client)

        args = { api_key: api_key, timeout: timeout_seconds }
        args[:base_url] = adapter.class::BASE_URL if adapter.class.const_defined?(:BASE_URL)
        real_client = ::OpenAI::Client.new(**args)
        adapter.instance_variable_set(:@client, SafeOpenAIClientProxy.new(real_client))
      end

      def api_key_for(provider, env)
        prefix, key_env = KEY_ENV_BY_PREFIX.find { |p, _| provider.start_with?(p) }
        raise BootstrapError, "Unsupported DSPY_PROVIDER: #{provider}" unless prefix

        key = env[key_env]
        if key.nil? || key.empty?
          raise BootstrapError,
            "#{key_env} is not set (required by DSPY_PROVIDER=#{provider})"
        end

        key
      end

      def connect_db(config)
        db = Database.connect(config.database_url)
        Database.setup_extensions(db)
        Migrator.new(db).run_all
        db
      rescue Sequel::Error => e
        raise BootstrapError,
          "Database connection failed for #{config.database_url}: #{e.message}"
      end
    end

    # Safe proxy class to wrap the OpenAI::Client and intercept chat completions
    class SafeOpenAIClientProxy
      def initialize(client)
        @client = client
      end

      def respond_to_missing?(method_name, include_private = false)
        @client.respond_to?(method_name, include_private) || super
      end

      def method_missing(method_name, *args, &block)
        res = @client.send(method_name, *args, &block)
        if method_name == :chat
          SafeChatProxy.new(res)
        else
          res
        end
      end
    end

    # Proxy to wrap the client.chat object and intercept completions call
    class SafeChatProxy
      def initialize(chat_proxy)
        @chat_proxy = chat_proxy
      end

      def respond_to_missing?(method_name, include_private = false)
        @chat_proxy.respond_to?(method_name, include_private) || super
      end

      def method_missing(method_name, *args, &block)
        res = @chat_proxy.send(method_name, *args, &block)
        if method_name == :completions
          SafeCompletionsProxy.new(res)
        else
          res
        end
      end
    end

    # Proxy to wrap the completions object and intercept create calls to validate responses
    class SafeCompletionsProxy
      def initialize(completions_proxy)
        @completions_proxy = completions_proxy
      end

      def respond_to_missing?(method_name, include_private = false)
        @completions_proxy.respond_to?(method_name, include_private) || super
      end

      def method_missing(method_name, *args, &block)
        if method_name == :create
          response = @completions_proxy.send(:create, *args, &block)

          if response.nil?
            raise "OpenAI API error: Response was nil"
          end

          # Check for API errors in the response hash or object
          err = if response.respond_to?(:error)
                  response.respond_to?(:dig) ? (response.error || response.dig("error") || response.dig(:error)) : response.error
                elsif response.is_a?(Hash)
                  response["error"] || response[:error]
                end

          if err
            message = if err.is_a?(Hash)
                        err["message"] || err[:message] || err.to_s
                      else
                        err.to_s
                      end
            raise "OpenAI API error: #{message}"
          end

          # Verify choices is not nil to prevent NoMethodError (undefined method 'first' for nil)
          choices = if response.respond_to?(:choices)
                      response.choices
                    elsif response.is_a?(Hash)
                      response["choices"] || response[:choices]
                    end

          if choices.nil?
            raise "OpenAI API error: Response was empty or missing 'choices'. Response: #{response.inspect}"
          end

          response
        else
          @completions_proxy.send(method_name, *args, &block)
        end
      end
    end
  end
end
