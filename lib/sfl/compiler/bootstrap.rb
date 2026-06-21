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
      def apply_request_timeout(lm, api_key, timeout_seconds)
        adapter = lm.instance_variable_get(:@adapter)
        client = adapter&.instance_variable_get(:@client)
        return unless defined?(::OpenAI::Client) && client.is_a?(::OpenAI::Client)

        args = { api_key: api_key, timeout: timeout_seconds }
        args[:base_url] = adapter.class::BASE_URL if adapter.class.const_defined?(:BASE_URL)
        adapter.instance_variable_set(:@client, ::OpenAI::Client.new(**args))
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
  end
end
