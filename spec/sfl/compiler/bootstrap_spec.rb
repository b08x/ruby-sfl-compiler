# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Bootstrap do
  # Pass env: as a plain Hash and load_dotenv: false so specs never touch
  # the real .env or process ENV.
  def call(env, require_db: false, require_llm: true, require_observability: false)
    described_class.call(
      require_db: require_db, require_llm: require_llm, require_observability: require_observability,
      env: env, load_dotenv: false
    )
  end

  describe "provider → API key resolution" do
    it "resolves openrouter providers from OPENROUTER_API_KEY" do
      ctx = call({ "DSPY_PROVIDER" => "openrouter/some/model",
                   "OPENROUTER_API_KEY" => "sk-or-test" })
      expect(ctx.config.dspy_provider).to eq("openrouter/some/model")
    end

    it "raises BootstrapError for an unsupported provider prefix" do
      expect {
        call({ "DSPY_PROVIDER" => "mystery/model", "OPENROUTER_API_KEY" => "x" })
      }.to raise_error(SFL::Compiler::BootstrapError, %r{Unsupported DSPY_PROVIDER: mystery/model})
    end

    it "raises BootstrapError when the provider's key is missing" do
      expect {
        call({ "DSPY_PROVIDER" => "openai/gpt-4o-mini" })
      }.to raise_error(SFL::Compiler::BootstrapError, /OPENAI_API_KEY/)
    end

    it "raises BootstrapError when the provider's key is empty" do
      expect {
        call({ "DSPY_PROVIDER" => "google/gemini-2.0-flash", "GOOGLE_API_KEY" => "" })
      }.to raise_error(SFL::Compiler::BootstrapError, /GOOGLE_API_KEY/)
    end
  end

  describe "LLM request timeout" do
    def configured_client
      DSPy.config.lm.instance_variable_get(:@adapter).instance_variable_get(:@client)
    end

    it "caps the OpenAI-family client timeout at the default 120s" do
      call({ "DSPY_PROVIDER" => "openrouter/some/model",
             "OPENROUTER_API_KEY" => "sk-or-test" })
      expect(configured_client.timeout).to eq(120.0)
    end

    it "honors SFL_LLM_TIMEOUT from the environment" do
      call({ "DSPY_PROVIDER" => "openrouter/some/model",
             "OPENROUTER_API_KEY" => "sk-or-test",
             "SFL_LLM_TIMEOUT" => "45" })
      expect(configured_client.timeout).to eq(45.0)
    end

    it "preserves the adapter's base_url when rebuilding the client" do
      call({ "DSPY_PROVIDER" => "openrouter/some/model",
             "OPENROUTER_API_KEY" => "sk-or-test" })
      expect(configured_client.inspect).to include("openrouter.ai")
    end
  end

  describe "require_llm: false" do
    it "skips DSPy configuration and key checks entirely" do
      ctx = call({}, require_llm: false)
      expect(ctx.db).to be_nil
      expect(ctx.config).to be(SFL::Compiler.config)
    end
  end

  describe "config propagation" do
    it "copies SPACY_MODEL and DATABASE_URL from env into config" do
      ctx = call({ "SPACY_MODEL" => "en_core_web_lg",
                   "DATABASE_URL" => "postgresql:///custom_db" }, require_llm: false)
      expect(ctx.config.spacy_model).to eq("en_core_web_lg")
      expect(ctx.config.database_url).to eq("postgresql:///custom_db")
    end

    it "copies VISION_MODEL from env into config" do
      ctx = call({ "VISION_MODEL" => "claude-sonnet-4-6" }, require_llm: false)
      expect(ctx.config.vision_model).to eq("claude-sonnet-4-6")
    end

    it "leaves vision_model nil when VISION_MODEL is absent" do
      ctx = call({}, require_llm: false)
      expect(ctx.config.vision_model).to be_nil
    end
  end

  describe "observability" do
    let(:instrumentation) { instance_double(OpenTelemetry::Instrumentation::RubyLLM::Instrumentation, install: true) }

    before do
      allow(OpenTelemetry::Instrumentation::RubyLLM::Instrumentation).to receive(:instance).and_return(instrumentation)
    end

    it "skips RubyLLM instrumentation when require_observability is false" do
      call({ "LANGFUSE_PUBLIC_KEY" => "pk", "LANGFUSE_SECRET_KEY" => "sk" },
        require_llm: false, require_observability: false)

      expect(instrumentation).not_to have_received(:install)
    end

    it "skips RubyLLM instrumentation when Langfuse keys are absent" do
      call({}, require_llm: false, require_observability: true)

      expect(instrumentation).not_to have_received(:install)
    end

    it "installs RubyLLM instrumentation when Langfuse keys are present" do
      call({ "LANGFUSE_PUBLIC_KEY" => "pk", "LANGFUSE_SECRET_KEY" => "sk" },
        require_llm: false, require_observability: true)

      expect(instrumentation).to have_received(:install)
    end

    it "wraps instrumentation install failures in BootstrapError" do
      allow(instrumentation).to receive(:install).and_raise(StandardError, "boom")

      expect {
        call({ "LANGFUSE_PUBLIC_KEY" => "pk", "LANGFUSE_SECRET_KEY" => "sk" },
          require_llm: false, require_observability: true)
      }.to raise_error(SFL::Compiler::BootstrapError, /Observability setup failed: boom/)
    end
  end

  describe "database connection failure" do
    it "wraps connection errors in BootstrapError" do
      allow(SFL::Compiler::Database).to receive(:connect)
        .and_raise(Sequel::DatabaseConnectionError, "connection refused")

      expect {
        call({ "DATABASE_URL" => "postgresql:///nope" }, require_db: true, require_llm: false)
      }.to raise_error(SFL::Compiler::BootstrapError, /Database connection failed.*connection refused/m)
    end
  end

  describe "job queue wiring (require_jobs: true)" do
    after { ActiveJob::Base.queue_adapter = :test }

    it "configures the sidekiq queue adapter and gush's redis_url from REDIS_URL" do
      described_class.call(
        require_db: false, require_llm: false, require_observability: false,
        require_jobs: true,
        env: { "REDIS_URL" => "redis://example.test:6380" },
        load_dotenv: false
      )

      expect(ActiveJob::Base.queue_adapter_name).to eq("sidekiq")
      expect(Gush.configuration.redis_url).to eq("redis://example.test:6380")
    end

    it "defaults redis_url to redis://localhost:6379 when REDIS_URL is unset" do
      described_class.call(
        require_db: false, require_llm: false, require_observability: false,
        require_jobs: true,
        env: {},
        load_dotenv: false
      )

      expect(Gush.configuration.redis_url).to eq("redis://localhost:6379")
    end

    it "does not configure jobs when require_jobs is false (the default)" do
      ActiveJob::Base.queue_adapter = :test

      described_class.call(
        require_db: false, require_llm: false, require_observability: false,
        env: {}, load_dotenv: false
      )

      expect(ActiveJob::Base.queue_adapter_name).to eq("test")
    end
  end

  describe SFL::Compiler::SafeOpenAIClientProxy do
    let(:raw_client) { double("OpenAI::Client") }
    let(:chat_proxy) { double("ChatProxy") }
    let(:completions_proxy) { double("CompletionsProxy") }
    let(:proxy) { described_class.new(raw_client) }

    before do
      allow(raw_client).to receive(:chat).and_return(chat_proxy)
      allow(chat_proxy).to receive(:completions).and_return(completions_proxy)
    end

    it "delegates ordinary completions and returns response if valid" do
      valid_response = double("Response", error: nil, choices: [double("Choice")])
      allow(completions_proxy).to receive(:create).and_return(valid_response)

      expect(proxy.chat.completions.create(foo: "bar")).to eq(valid_response)
    end

    it "raises an error if the response indicates an API error" do
      error_response = double("Response", error: { "message" => "Rate limit exceeded" })
      allow(completions_proxy).to receive(:create).and_return(error_response)

      expect {
        proxy.chat.completions.create(foo: "bar")
      }.to raise_error(RuntimeError, /OpenAI API error: Rate limit exceeded/)
    end

    it "raises an error if choices is nil" do
      nil_choices_response = double("Response", error: nil, choices: nil)
      allow(completions_proxy).to receive(:create).and_return(nil_choices_response)

      expect {
        proxy.chat.completions.create(foo: "bar")
      }.to raise_error(RuntimeError, /Response was empty or missing 'choices'/)
    end
  end
end
