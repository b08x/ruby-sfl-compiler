# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Bootstrap do
  # Pass env: as a plain Hash and load_dotenv: false so specs never touch
  # the real .env or process ENV.
  def call(env, require_db: false, require_llm: true)
    described_class.call(
      require_db: require_db, require_llm: require_llm,
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
  end
end
