# frozen_string_literal: true

# Entry point for `bundle exec sidekiq -q gush -r lib/sfl/compiler/sidekiq_boot.rb`.
#
# Sidekiq's CLI auto-detects a Rails app (config/environment.rb) and
# requires an explicit -r otherwise — sfl-compiler isn't Rails, so without
# this file the worker process never loads SFL::Compiler::CompileTurnJob /
# ReduceTurnsJob at all, and never defines Sidekiq::ActiveJob::Wrapper
# (only Bootstrap#configure_jobs does that, and nothing else calls it in a
# worker boot path). require_db/require_llm/require_observability are off
# here because Bootstrap.call is invoked again, for real, inside each job's
# own #perform (see CompileTurnJob#pipeline) — this boot file only needs to
# make Gush/ActiveJob/Sidekiq wiring exist before the worker starts pulling
# jobs off the queue.
require "sfl/compiler"

SFL::Compiler::Bootstrap.call(
  require_db: false,
  require_llm: false,
  require_observability: false,
  require_jobs: true
)
