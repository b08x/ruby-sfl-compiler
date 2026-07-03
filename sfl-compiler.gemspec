# frozen_string_literal: true

require_relative "lib/sfl/compiler/version"

Gem::Specification.new do |spec|
  spec.name = "sfl-compiler"
  spec.version = SFL::Compiler::VERSION
  spec.authors = ["Syncopated Context"]
  spec.email = ["dev@syncopated.io"]

  spec.summary = "Two-Pass SFL Compiler for high-fidelity RAG"
  spec.description = "Separates syntactic extraction from semantic annotation using " \
    "ruby-spacy and dspy.rb, producing multi-layered indexable " \
    "payloads with scalar filtering on interpersonal features."
  spec.homepage = "https://github.com/syncopated/sfl-compiler"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.4.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z 2>/dev/null`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end

  spec.require_paths = ["lib"]
  spec.bindir = "exe"
  spec.executables = %w[sfl-analyze sfl-api]
  spec.extensions = ["ext/sfl_compiler/extconf.rb"]

  spec.add_dependency "amatch", "~> 0.7"
  spec.add_dependency "async", "~> 2.21"
  spec.add_dependency "bubbles", "~> 0.1"
  spec.add_dependency "bubbletea", "~> 0.1"
  spec.add_dependency "circuit_breaker", "~> 1.1"
  spec.add_dependency "csv", "~> 3.3"
  spec.add_dependency "dotenv", "~> 3.1"
  spec.add_dependency "dry-monads", "~> 1.6"
  spec.add_dependency "dry-struct", "~> 1.6"
  spec.add_dependency "dry-types", "~> 1.7"
  spec.add_dependency "dspy", "~> 1.0"
  spec.add_dependency "dspy-o11y", "~> 1.0"
  spec.add_dependency "dspy-o11y-langfuse", "~> 1.1"
  spec.add_dependency "dspy-openai", "~> 1.0"
  spec.add_dependency "falcon", "~> 0.48"
  spec.add_dependency "glamour", "~> 0.2"
  spec.add_dependency "gum"
  spec.add_dependency "inkmark", "~> 0.1"
  spec.add_dependency "journald-logger", "~> 3.1"
  spec.add_dependency "kreuzberg", "~> 4.9"
  spec.add_dependency "lipgloss", "~> 0.2"
  spec.add_dependency "opentelemetry-exporter-otlp", "~> 0.34.0"
  spec.add_dependency "opentelemetry-instrumentation-ruby_llm", "~> 0.6.0"
  spec.add_dependency "opentelemetry-sdk", "~> 1.12"
  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "pg", "~> 1.5"
  spec.add_dependency "pgvector", "~> 0.3"
  spec.add_dependency "pragmatic_segmenter", "~> 0.3"
  spec.add_dependency "pragmatic_tokenizer", "~> 3.0"
  spec.add_dependency "prime", "~> 0.1"
  spec.add_dependency "ruby_llm", "~> 1.3"
  spec.add_dependency "ruby-spacy", "~> 0.4"
  spec.add_dependency "sequel", "~> 5.88"
  spec.add_dependency "tomoto", "~> 0.3"
  spec.add_dependency "tty-progressbar", "~> 0.18"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "yajl-ruby", "~> 1.4"
  spec.add_dependency "zeitwerk", "~> 2.7"
end
