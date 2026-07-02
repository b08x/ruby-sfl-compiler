# frozen_string_literal: true

module SFL
  module Compiler
    # Bootstrap wiring for the Falcon HTTP API server (exe/sfl-api).
    #
    # Skips Pass 1 (PyCall/spaCy) — SFL compilation runs inside Sidekiq
    # worker processes, never in the HTTP server process. The API only
    # needs DB (retrieval/storage) and DSPy LM (synthesis).
    module APIBoot
      module_function

      # @param env [#[]] environment source, injectable for tests
      # @return [Bootstrap::Context]
      def call(env: ENV)
        Bootstrap.call(
          require_db:            true,
          require_llm:           true,
          require_observability: true,
          require_jobs:          true,   # workflow endpoints need Gush configured
          env:                   env,
          load_dotenv:           false   # config.ru already loaded .env
        )
      end
    end
  end
end
