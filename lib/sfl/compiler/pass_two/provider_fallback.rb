# frozen_string_literal: true

module SFL
  module Compiler
    # Builds and manages a provider fallback chain for Pass 2 LLM calls.
    #
    # Each entry in the chain is a {provider:, lm:} struct. PassTwoEngine
    # tries entries in order, using the first that succeeds. The primary
    # provider is always first; additional providers come from
    # SFL_FALLBACK_PROVIDERS (comma-separated) in the environment.
    #
    # LM instances are per-entry and do NOT touch DSPy.config.lm, so
    # threads using different entries never race on the global LM.
    #
    # Generation params (temperature, top_p, top_k) are injected into
    # each entry's LM adapter via a singleton override on
    # `prepare_chat_instance`, mirroring how Bootstrap patches the HTTP
    # timeout client — invasive but consistent with the existing pattern.
    module ProviderFallback
      ProviderEntry = Struct.new(:provider, :lm, keyword_init: true)

      GENERATION_ENV_KEYS = {
        temperature: "SFL_TEMPERATURE",
        top_p:       "SFL_TOP_P",
        top_k:       "SFL_TOP_K",
      }.freeze

      class << self
        # Build a chain from the primary provider + SFL_FALLBACK_PROVIDERS.
        # Providers whose API keys are missing are skipped with a warning.
        #
        # @param primary [String] the main DSPY_PROVIDER value
        # @param env [#[]] environment source
        # @return [Array<ProviderEntry>] at least one entry (the primary)
        def build_chain(primary, env: ENV)
          extras   = env.fetch("SFL_FALLBACK_PROVIDERS", "").split(",").map(&:strip).reject(&:empty?)
          gen_params = read_generation_params(env)

          [primary, *extras].filter_map do |provider|
            lm = build_lm(provider, env, gen_params)
            ProviderEntry.new(provider:, lm:)
          rescue BootstrapError => e
            warn "[WARN] ProviderFallback: skipping #{provider} — #{e.message}"
            nil
          end
        end

        # Translate a raw exception into a human-readable description of
        # what went wrong semantically.
        #
        # @param error [Exception]
        # @param provider [String]
        # @param timeout [Numeric, nil]
        # @return [String]
        def classify_error(error, provider:, timeout: nil)
          msg = error.message.to_s
          case error
          when Timeout::Error
            "#{provider} did not respond within #{timeout&.round}s (network hang or overloaded endpoint)"
          else
            if msg.match?(/429|rate.?limit/i)
              "#{provider} rate-limited the request — too many requests, back off"
            elsif msg.match?(/401|403|unauthorized|forbidden/i)
              "#{provider} rejected credentials — check API key for #{provider.split('/').first}"
            elsif msg.match?(/400|bad.?request/i)
              "#{provider} rejected the request body — check model name or prompt format"
            elsif msg.match?(/502|503|504|unavailable/i)
              "#{provider} temporarily unavailable (#{msg[/\d{3}/] || 'upstream error'})"
            elsif msg.match?(/Prediction validation failed|Missing required prop/i)
              "#{provider} returned a response that does not match the SFL schema " \
                "(structured_outputs: true requires a model that reliably follows JSON schema — " \
                "reasoning/vision models often fail this; try a different DSPY_PROVIDER)"
            elsif msg.match?(/json|parse|unexpected.token/i)
              "#{provider} returned malformed JSON — structured output may not be supported by this model"
            else
              "#{provider} error: #{msg}"
            end
          end
        end

        private

        # Read generation parameters from env, coercing to the right types.
        def read_generation_params(env)
          GENERATION_ENV_KEYS.filter_map do |key, env_key|
            val = env[env_key]
            next if val.nil? || val.empty?
            [key, key == :top_k ? val.to_i : val.to_f]
          end.to_h
        end

        # Build a DSPy::LM with HTTP timeout + generation params applied,
        # without touching the global DSPy.configure.
        def build_lm(provider, env, gen_params = {})
          key = Bootstrap.api_key_for(provider, env)
          lm  = DSPy::LM.new(provider, api_key: key, structured_outputs: true)
          Bootstrap.apply_request_timeout(lm, key,
            (env["SFL_LLM_TIMEOUT"] || Bootstrap::DEFAULT_LLM_TIMEOUT).to_f)
          apply_generation_params(lm, gen_params) unless gen_params.empty?
          lm
        end

        # Inject temperature/top_p/top_k into the adapter's prepare_chat_instance
        # so they apply to every Chat instance the adapter creates.
        # Uses the same singleton-method-override pattern as Bootstrap#apply_request_timeout.
        def apply_generation_params(lm, params)
          adapter = lm.instance_variable_get(:@adapter)
          return unless adapter

          temperature = params[:temperature]
          extra       = params.slice(:top_p, :top_k)
          return if temperature.nil? && extra.empty?

          original_prepare = adapter.method(:prepare_chat_instance)
          adapter.define_singleton_method(:prepare_chat_instance) do |chat_instance, messages, signature|
            ci = original_prepare.call(chat_instance, messages, signature)
            ci = ci.with_temperature(temperature) if temperature
            ci = ci.with_params(**extra)          unless extra.empty?
            ci
          end
        end
      end
    end
  end
end
