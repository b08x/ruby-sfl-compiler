# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
require "spec_helper"
require "open3"
require "tempfile"

# Regression guard for the require-ordering bug found in this session:
# dspy-o11y-langfuse reads LANGFUSE_PUBLIC_KEY/SECRET_KEY from ENV the
# moment "dspy" is required (it auto-configures the global OpenTelemetry
# SDK right then, one-shot) — so tracing only activates if a .env FILE
# has already been loaded into ENV by that point. spec_helper.rb requires
# "sfl/compiler" (and thus "dspy") at file load time, before any example
# runs, so this can only be verified in a real subprocess with a
# controlled require order — never in-process. dspy-o11y-langfuse's own
# test_environment? check (`defined?(RSpec)`) disables it unconditionally
# in-process anyway.
#
# The fake keys are deliberately written to a temp .env FILE rather than
# passed as real subprocess ENV vars — passing them directly as ENV vars
# would make them present from process start regardless of Dotenv.load's
# position in the script, defeating the entire point of this test.
RSpec.describe "observability require ordering" do
  let(:root) { File.expand_path("../../..", __dir__) }

  around do |example|
    Tempfile.create(["sfl_compiler_test_", ".env"]) do |f|
      f.write("LANGFUSE_PUBLIC_KEY=pk-test\nLANGFUSE_SECRET_KEY=sk-test\n")
      f.flush
      @env_file = f.path
      example.run
    end
  end

  # Bundler.with_unbundled_env is required here: this spec already runs
  # inside a `bundle exec rspec` process, whose Bundler env vars (gem path,
  # bin path resolution) get inherited by a naive Open3.capture2 and break
  # the child `bundle exec ruby` invocation with a nested-Bundler LoadError.
  def tracer_provider_class(script)
    out, status = Bundler.with_unbundled_env do
      Open3.capture2({}, "bundle", "exec", "ruby", "-e", script, chdir: root)
    end
    raise "subprocess failed:\n#{out}" unless status.success?

    out.strip
  end

  it "configures a real OTel SDK tracer when .env loads before sfl-compiler is required" do
    script = <<~RUBY
      $LOAD_PATH.unshift(File.expand_path("lib"))
      require "dotenv"
      Dotenv.load(#{@env_file.inspect})
      require "sfl-compiler"
      SFL::Compiler::Bootstrap # Zeitwerk autoloads bootstrap.rb (and its "require dspy") lazily
      require "opentelemetry/sdk"
      puts OpenTelemetry.tracer_provider.class
    RUBY

    expect(tracer_provider_class(script)).to eq("OpenTelemetry::SDK::Trace::TracerProvider")
  end

  it "leaves tracing disabled when sfl-compiler is required before .env loads (the regression this guards against)" do
    script = <<~RUBY
      $LOAD_PATH.unshift(File.expand_path("lib"))
      require "sfl-compiler"
      SFL::Compiler::Bootstrap # Zeitwerk autoloads bootstrap.rb (and its "require dspy") lazily
      require "dotenv"
      Dotenv.load(#{@env_file.inspect})
      require "opentelemetry/sdk"
      puts OpenTelemetry.tracer_provider.class
    RUBY

    expect(tracer_provider_class(script)).to eq("OpenTelemetry::Internal::ProxyTracerProvider")
  end
end
# rubocop:enable Metrics/BlockLength
