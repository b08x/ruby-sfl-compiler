# frozen_string_literal: true

require "socket"
require "uri"

module SFL
  module Compiler
    # Pre-flight Langfuse/OpenTelemetry connectivity check, run from
    # exe/sfl-analyze BEFORE `require "sfl-compiler"`. By the time any
    # code inside the gem runs, dspy-o11y-langfuse has already made its
    # one-shot decision to configure (or skip) OTel tracing by reading
    # LANGFUSE_PUBLIC_KEY/SECRET_KEY from ENV at require-time (see
    # Bootstrap's own file-top comment on this). There is no later hook
    # to undo that — the only way to act on "the tracing endpoint is
    # unreachable" is to unset those ENV vars before that require ever
    # happens.
    #
    # Deliberately NOT autoloaded via Zeitwerk (see lib/sfl/compiler.rb's
    # loader.ignore for this file) — it must be loadable standalone,
    # before the gem's own Zeitwerk setup runs.
    module LangfuseReachability
      # @param host_url [String]
      # @param timeout [Numeric] seconds
      # @return [Boolean]
      module_function def reachable?(host_url, timeout: 2)
        uri = URI.parse(host_url)
        port = uri.port || ((uri.scheme == "https") ? 443 : 80)
        Socket.tcp(uri.host, port, connect_timeout: timeout) { true }
      rescue
        false
      end

      # @param env [#[]] e.g. ENV
      # @param tty [Boolean] whether stdin is interactive
      # @param input [#gets] injectable for tests
      # @return [Symbol] :traced (no keys configured, or reachable),
      #   :skip_tracing (keys present but endpoint unreachable — continue
      #   without tracing), or :cancel (unreachable, interactive, user
      #   declined)
      module_function def decide(env:, tty:, input: $stdin)
        return :traced unless tracing_requested?(env)
        return :traced if reachable?(env["LANGFUSE_HOST"])

        explain_unreachable(env)
        return :skip_tracing unless tty

        prompt_to_continue(input)
      end

      module_function def tracing_requested?(env)
        env["LANGFUSE_PUBLIC_KEY"] && env["LANGFUSE_SECRET_KEY"] && env["LANGFUSE_HOST"]
      end

      module_function def explain_unreachable(env)
        warn "[WARN] Cannot reach Langfuse at #{env['LANGFUSE_HOST']} — " \
          "tracing would fail/spam errors throughout the run."
      end

      module_function def prompt_to_continue(input)
        warn "Continue without tracing? [y/N, N cancels the job] "
        (input.gets&.strip&.downcase == "y") ? :skip_tracing : :cancel
      end
    end
  end
end
