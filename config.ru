# frozen_string_literal: true
# Rack entry point for `bundle exec falcon serve` / `bundle exec sfl-api`.

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require "dotenv"
begin
  Dotenv.load
rescue StandardError => e
  warn "[WARN] .env failed to load: #{e.message}"
end

# Must run before "sfl-compiler" is required — DSPy configures Langfuse
# tracing from ENV at require-time, one-shot.
require_relative "lib/sfl/compiler/langfuse_reachability"
if SFL::Compiler::LangfuseReachability.decide(env: ENV, tty: false) == :skip_tracing
  ENV.delete("LANGFUSE_PUBLIC_KEY")
  ENV.delete("LANGFUSE_SECRET_KEY")
end

require "sfl-compiler"
require_relative "lib/sfl/compiler/api_boot"
require_relative "lib/sfl/compiler/api"

ctx = SFL::Compiler::APIBoot.call
run SFL::Compiler::API::Server.new(ctx)
