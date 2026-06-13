# frozen_string_literal: true

source "https://rubygems.org"

# NLP & LLM
gem "dspy", "~> 1.0"
gem "dspy-openai", "~> 1.0" # For OpenAI and OpenRouter
gem "inkmark", "~> 0.1"
gem "pragmatic_segmenter", "~> 0.3"
gem "pragmatic_tokenizer", "~> 3.0"
gem "ruby_llm", "~> 1.3"
gem "ruby-spacy", "~> 0.4"

# Database
gem "pg", "~> 1.5"
gem "pgvector", "~> 0.3"
gem "sequel", "~> 5.88"

# Resilience
gem "circuit_breaker", "~> 1.1"

# Logging
gem "journald-logger", "~> 3.1"

# Type Safety
gem "dry-monads", "~> 1.6"
gem "dry-struct", "~> 1.6"
gem "dry-types", "~> 1.7"

# Environment
gem "dotenv", "~> 3.1"

# Autoloading
gem "zeitwerk", "~> 2.7"

# Output Formats
gem "csv", "~> 3.3"

group :development, :test do
  gem "pry"
  gem "pry-byebug"
  gem "rake"
  gem "rspec"
  gem "rubocop"
  gem "rubocop-factory_bot"
  gem "rubocop-minitest"
  gem "rubocop-packaging"
  gem "rubocop-performance"
  gem "rubocop-rake"
  gem "rubocop-rspec"
  gem "rubocop-sequel"
  gem "rubocop-shopify"
  gem "rubocop-thread_safety"
end

group :quality do
  gem "git-lint"
  gem "simplecov", require: false
end

gem "ruby-lsp", "~> 0.26.9"
