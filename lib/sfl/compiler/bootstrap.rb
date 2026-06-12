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

        configure_llm(config.dspy_provider, env) if require_llm
        db = connect_db(config) if require_db

        Context.new(db: db, config: config)
      end

      def configure_llm(provider, env)
        key = api_key_for(provider, env)
        DSPy.configure do |c|
          c.lm = DSPy::LM.new(provider, api_key: key, structured_outputs: true)
        end
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
