# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::ProviderFallback do
  describe ".classify_error" do
    def classify(message, timeout: 90)
      error = RuntimeError.new(message)
      described_class.classify_error(error, provider: "openrouter/some/model", timeout:)
    end

    it "classifies Timeout::Error" do
      error = Timeout::Error.new("execution expired")
      result = described_class.classify_error(error, provider: "openrouter/some/model", timeout: 90)
      expect(result).to include("did not respond within 90s")
    end

    it "classifies rate-limit errors" do
      expect(classify("429 Too Many Requests")).to include("rate-limited")
    end

    it "classifies credential errors" do
      expect(classify("401 Unauthorized")).to include("rejected credentials")
    end

    it "classifies bad-request errors" do
      expect(classify("400 Bad Request")).to include("rejected the request body")
    end

    it "classifies upstream unavailability" do
      expect(classify("503 Service Unavailable")).to include("temporarily unavailable")
    end

    it "classifies DSPy structured-output validation failure with an actionable message" do
      msg = "Prediction validation failed:\n\nMissing required prop `annotations` for class ``"
      result = classify(msg)
      expect(result).to include("does not match the SFL schema")
      expect(result).to include("structured_outputs: true")
      expect(result).to include("DSPY_PROVIDER")
    end

    it "classifies malformed JSON from the model" do
      expect(classify("unexpected token in JSON")).to include("malformed JSON")
    end

    it "falls through to a generic message for unknown errors" do
      expect(classify("some obscure network blip")).to include("some obscure network blip")
    end
  end
end
