# frozen_string_literal: true

require "dotenv"
require "dspy"
require "opentelemetry-instrumentation-ruby_llm"

# `require "dspy"` (above) transitively requires dspy-o11y-langfuse (dspy
# core conditionally pulls it in if the gem is installed) and, at the very
# bottom of dspy's own load, calls DSPy::Observability.configure! — which
# reads LANGFUSE_PUBLIC_KEY/SECRET_KEY from ENV right then, one-shot. By
# the time this method's Dotenv.load runs, that decision has already been
# made with whatever ENV looked like beforehand. This is harmless ONLY
# because every entry point (exe/sfl-analyze, scripts/*.rb) loads .env
# before requiring "sfl-compiler" at all — if a new entry point requires
# this gem without doing that first, tracing will silently stay disabled
# no matter what Bootstrap does here.

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
        "anthropic/" => "ANTHROPIC_API_KEY",
      }.freeze

      module_function

      # @param require_db [Boolean] connect + migrate the database
      # @param require_llm [Boolean] configure DSPy (false for --pass1-only)
      # @param require_jobs [Boolean] configure ActiveJob + Gush
      # @param env [#[]] environment source, injectable for tests
      # @param load_dotenv [Boolean] read .env first (off in tests)
      # @return [Context]
      def call(require_db: true, require_llm: true, require_observability: true, require_jobs: false, env: ENV, load_dotenv: true)
        Dotenv.load if load_dotenv

        config = SFL::Compiler.config
        config.database_url = env["DATABASE_URL"] if env["DATABASE_URL"]
        config.spacy_model = env["SPACY_MODEL"] if env["SPACY_MODEL"]
        config.dspy_provider = env["DSPY_PROVIDER"] if env["DSPY_PROVIDER"]
        config.ollama_base_url = env["OLLAMA_BASE_URL"] if env["OLLAMA_BASE_URL"]
        config.embedding_model = env["EMBEDDING_MODEL"] if env["EMBEDDING_MODEL"]
        config.vision_model    = env["VISION_MODEL"]    if env["VISION_MODEL"]

        configure_llm(config.dspy_provider, env) if require_llm
        configure_observability(env) if require_observability
        configure_jobs(env) if require_jobs
        db = connect_db(config) if require_db

        Context.new(db:, config:)
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

        args = { api_key:, timeout: timeout_seconds }
        args[:base_url] = adapter.class::BASE_URL if adapter.class.const_defined?(:BASE_URL)
        real_client = ::OpenAI::Client.new(**args)
        adapter.instance_variable_set(:@client, SafeOpenAIClientProxy.new(real_client))
      end

      # By this point dspy-o11y-langfuse has already made its one-shot
      # decision (see the file-top comment on `require "dspy"`) — this
      # guard just mirrors that decision so RubyLLM spans (Embedder,
      # ThemeRhemeExtractor) don't get installed against a no-op tracer.
      # `.install` attaches to whatever global TracerProvider already
      # exists; it must NOT be a second OpenTelemetry::SDK.configure call,
      # which can only run once per process and would raise here.
      def configure_observability(env)
        return unless env["LANGFUSE_PUBLIC_KEY"] && env["LANGFUSE_SECRET_KEY"]

        OpenTelemetry::Instrumentation::RubyLLM::Instrumentation.instance.install
      rescue => e
        raise BootstrapError, "Observability setup failed: #{e.message}"
      end

      # Gush workers (Sidekiq processes) are their own entry points, same
      # as exe/sfl-analyze — each one must wire its own environment via
      # Bootstrap rather than relying on a shared in-process Gush.configure
      # call, since a worker may start in a different process entirely.
      def configure_jobs(env)
        require "active_job"
        require "sidekiq"
        require "gush"

        # sidekiq < 8.0's ActiveJob integration (Sidekiq::ActiveJob::Wrapper)
        # only got defined via lib/sidekiq/rails.rb, which unconditionally
        # requires "rails" — raising NameError outside Rails. sidekiq 8.0
        # moved that definition into lib/active_job/queue_adapters/sidekiq_adapter.rb
        # itself, gated only on `gem "activejob", ">= 7.0"`, so it now works
        # standalone (verified against sidekiq 8.1.6). Pin stays >= 8.0;
        # don't downgrade without re-adding the old Rails-independent
        # Wrapper workaround this replaced.
        ActiveJob::Base.queue_adapter = :sidekiq
        Gush.configure do |c|
          c.redis_url = env["REDIS_URL"] || "redis://localhost:6379"
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

    # Safe proxy class to wrap the OpenAI::Client and intercept chat completions
    class SafeOpenAIClientProxy
      def initialize(client)
        @client = client
      end

      def respond_to_missing?(method_name, include_private = false)
        @client.respond_to?(method_name, include_private) || super
      end

      def method_missing(method_name, *, &)
        res = @client.send(method_name, *, &)
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

      def method_missing(method_name, *, &)
        res = @chat_proxy.send(method_name, *, &)
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

      def method_missing(method_name, *, &)
        if method_name == :create
          response = @completions_proxy.send(:create, *, &)

          raise "OpenAI API error: Response was nil" if response.nil?

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
          @completions_proxy.send(method_name, *, &)
        end
      end
    end
  end
end
