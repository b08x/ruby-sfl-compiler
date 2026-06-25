# frozen_string_literal: true

require "spec_helper"
require "gush"

RSpec.describe SFL::Compiler::CrabConstraintJob do
  def job_with_claims(claims, invariants: [])
    job = described_class.new(params: { invariants: })
    job.payloads = [{ id: "prior-1", class: "SprintRoleJob", output: { "claims" => claims } }]
    job
  end

  it "passes a claim through when it violates no invariant" do
    invariant = { "name" => "min_modality", "field" => "modality_weight", "op" => "gte", "value" => 0.5 }
    job = job_with_claims([{ "modality_weight" => 0.8 }], invariants: [invariant])

    job.perform

    expect(job.output_payload[:passed_claims]).to eq([{ "modality_weight" => 0.8 }])
    expect(job.output_payload[:rejected_claims]).to eq([])
  end

  it "rejects a claim that violates a supplied invariant, with the reason recorded" do
    invariant = { "name" => "min_modality", "field" => "modality_weight", "op" => "gte", "value" => 0.5 }
    job = job_with_claims([{ "modality_weight" => 0.2 }], invariants: [invariant])

    job.perform

    expect(job.output_payload[:passed_claims]).to eq([])
    expect(job.output_payload[:rejected_claims]).to eq([{ "modality_weight" => 0.2 }])
    expect(job.output_payload[:violations].first["name"]).to eq("min_modality")
    expect(job.output_payload[:violations].first["reason"]).to include("0.2")
  end

  it "passes everything through unchanged when given no invariants" do
    claims = [{ "modality_weight" => 0.1 }, { "modality_weight" => 0.9 }]
    job = job_with_claims(claims, invariants: [])

    job.perform

    expect(job.output_payload[:passed_claims]).to eq(claims)
    expect(job.output_payload[:rejected_claims]).to eq([])
  end

  it "partitions a fixture set using the documentation track's two known invariants" do
    fallback_exclusion = {
      "name" => "fallback_excluded",
      "field" => "annotation_source",
      "op" => "neq",
      "value" => "fallback",
    }
    min_clause_threshold = { "name" => "min_clause_threshold", "field" => "clause_count", "op" => "gte", "value" => 30 }

    claims = [
      { "annotation_source" => "llm", "clause_count" => 42 },        # passes both
      { "annotation_source" => "fallback", "clause_count" => 42 },   # fails fallback_excluded
      { "annotation_source" => "llm", "clause_count" => 10 },        # fails min_clause_threshold
    ]
    job = job_with_claims(claims, invariants: [fallback_exclusion, min_clause_threshold])

    job.perform

    expect(job.output_payload[:passed_claims]).to eq([claims[0]])
    expect(job.output_payload[:rejected_claims]).to eq([claims[1], claims[2]])
    expect(job.output_payload[:violations].map { |v| v["name"] }).to eq(%w[fallback_excluded min_clause_threshold])
  end
end
