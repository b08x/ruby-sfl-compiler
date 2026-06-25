# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::DerivationHash do
  let(:premises) do
    [
      SFL::Compiler::Types::Premise.new(type: "token", source: "unanimously", value: "ADV", weight: 0.7),
      SFL::Compiler::Types::Premise.new(type: "pos", source: "DET+VERB", value: "formal_pattern", weight: nil),
    ]
  end

  it "is deterministic for the same premises/inference_rule/conclusion" do
    a = described_class.compute(premises:, inference_rule: "rule_a", conclusion: { tenor: 0.8 })
    b = described_class.compute(premises:, inference_rule: "rule_a", conclusion: { tenor: 0.8 })

    expect(a).to eq(b)
  end

  it "is order-independent over premises" do
    a = described_class.compute(premises:, inference_rule: "rule_a", conclusion: { tenor: 0.8 })
    b = described_class.compute(premises: premises.reverse, inference_rule: "rule_a", conclusion: { tenor: 0.8 })

    expect(a).to eq(b)
  end

  it "changes when the conclusion changes" do
    a = described_class.compute(premises:, inference_rule: "rule_a", conclusion: { tenor: 0.8 })
    b = described_class.compute(premises:, inference_rule: "rule_a", conclusion: { tenor: 0.1 })

    expect(a).not_to eq(b)
  end

  it "produces the same hash for symbol-keyed and string-keyed plain Hash premises" do
    struct_hash = described_class.compute(premises:, inference_rule: "rule_a", conclusion: { "tenor" => 0.8 })

    plain_hashes = [
      { "type" => "token", "source" => "unanimously", "value" => "ADV", "weight" => 0.7 },
      { "type" => "pos", "source" => "DET+VERB", "value" => "formal_pattern", "weight" => nil },
    ]
    plain_hash_result = described_class.compute(premises: plain_hashes, inference_rule: "rule_a",
      conclusion: { tenor: 0.8 })

    expect(struct_hash).to eq(plain_hash_result)
  end
end
