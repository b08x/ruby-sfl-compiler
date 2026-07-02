# frozen_string_literal: true

# API manifest — explicitly required by config.ru, never autoloaded by
# Zeitwerk (the api/ directory is ignored in lib/sfl/compiler.rb).
require_relative "api/server"
