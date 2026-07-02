# frozen_string_literal: true

require "spec_helper"
require "sequel"
require "gush"
require "dspy"

RSpec.describe SFL::Compiler::IntermediateGenieJob do
  def db_row(process_type: "material", mood: "declarative", tenor: 0.6, modality: 0.7)
    {
      clause:        { text: "The system processes data.", external_id: "c1" },
      ideational:    { process_type:, participants: [{ "text" => "system" }],
                       circumstances: [] },
      interpersonal: { mood:, tenor:, modality_weight: modality,
                       annotation_source: "llm" },
      embedding:     nil
    }
  end

  let(:clause_ids) { %w[c1 c2] }
  let(:rows)       { [db_row(process_type: "material"), db_row(process_type: "relational", tenor: 0.4)] }

  let(:clause_repo) { instance_double(SFL::Compiler::ClauseRepository) }
  let(:summary_repo) { instance_double(SFL::Compiler::AxiomaticSummaryRepository) }
  let(:ctx)  { double("BootstrapContext", db: double("db"), config: double(dspy_provider: "openrouter/test")) }

  let(:predictor) { instance_double(DSPy::ChainOfThought) }
  let(:prediction) do
    double("Prediction",
      summary:    "Axiomatic summary prose.",
      core_claim: "Material processes dominate.")
  end
  let(:lm_config) { double("LMConfig").as_null_object }

  before do
    Sequel.singleton_class.define_method(:pg_jsonb) { |v| v } unless Sequel.respond_to?(:pg_jsonb)

    allow(SFL::Compiler::Bootstrap).to receive(:call).and_return(ctx)
    allow(SFL::Compiler::Bootstrap).to receive(:api_key_for).and_return("test-key")

    allow(SFL::Compiler::ClauseRepository).to receive(:new).and_return(clause_repo)
    allow(SFL::Compiler::AxiomaticSummaryRepository).to receive(:new).and_return(summary_repo)

    allow(clause_repo).to receive(:find).with("c1").and_return(rows[0])
    allow(clause_repo).to receive(:find).with("c2").and_return(rows[1])

    allow(summary_repo).to receive(:store).and_return({
      id: "sum-uuid-1", summary_text: "Axiomatic summary prose.",
      core_claim: "Material processes dominate.", clause_count: 2
    })

    allow(DSPy::ChainOfThought).to receive(:new).and_return(predictor)
    allow(predictor).to receive(:configure).and_yield(lm_config)
    allow(predictor).to receive(:call).and_return(prediction)
  end

  def job_for(clause_ids)
    described_class.new(params: { clause_ids:, workflow_id: "wf-test" })
  end

  describe "#perform" do
    it "fetches each clause from the repository" do
      job_for(clause_ids).perform

      expect(clause_repo).to have_received(:find).with("c1")
      expect(clause_repo).to have_received(:find).with("c2")
    end

    it "stores the summary with correct aggregates" do
      job_for(clause_ids).perform

      expect(summary_repo).to have_received(:store).with(
        hash_including(
          workflow_id: "wf-test",
          source_clause_ids: clause_ids,
          summary_text: "Axiomatic summary prose.",
          core_claim: "Material processes dominate.",
          clause_count: 2
        )
      )
    end

    it "outputs summary_id and summary_text" do
      job = job_for(clause_ids)
      job.perform

      expect(job.output_payload).to include(
        summary_id:   "sum-uuid-1",
        summary_text: "Axiomatic summary prose."
      )
    end

    it "computes correct avg_tenor from both rows" do
      job_for(clause_ids).perform

      expect(summary_repo).to have_received(:store).with(
        hash_including(avg_tenor: be_within(0.001).of(0.5))  # (0.6 + 0.4) / 2
      )
    end

    it "builds process_type_distribution as fractions" do
      job_for(clause_ids).perform

      expect(summary_repo).to have_received(:store).with(
        hash_including(
          process_type_distribution: hash_including(
            "material" => 0.5,
            "relational" => 0.5
          )
        )
      )
    end

    context "when the LLM call fails" do
      before { allow(predictor).to receive(:call).and_raise(StandardError, "LLM error") }

      it "falls back to prose summary without raising" do
        job = job_for(clause_ids)
        expect { job.perform }.not_to raise_error

        expect(summary_repo).to have_received(:store).with(
          hash_including(summary_text: match(/Axiomatic summary/))
        )
      end
    end

    context "when no clause IDs resolve" do
      before do
        allow(clause_repo).to receive(:find).and_return(nil)
      end

      it "stores an empty aggregate summary" do
        job_for(clause_ids).perform

        expect(summary_repo).to have_received(:store).with(
          hash_including(clause_count: 0, avg_tenor: 0.5)
        )
      end
    end
  end
end
