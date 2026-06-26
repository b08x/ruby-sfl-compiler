# frozen_string_literal: true

require "spec_helper"
require "gush"
require_relative "../../../../lib/sfl/compiler/tui/workflow_poller"

RSpec.describe SFL::Compiler::TUI::WorkflowPoller do
  # Build a minimal fake Gush job without loading Redis/ActiveJob.
  def fake_job(klass:, finished: false, running: false, failed: false, params: {}, output: nil)
    double("Gush::Job",
      klass: klass,
      finished?: finished,
      running?: running,
      failed?: failed,
      params: params,
      output_payload: output
    )
  end

  def fake_workflow(jobs:, status: :running)
    dbl = double("Gush::Workflow", jobs:, status:)
    allow(dbl).to receive(:reload) { dbl }
    dbl
  end

  let(:workflow_id) { "abc-123" }

  before do
    # Prevent real Redis calls — return our fake workflow from the class method.
    allow(Gush::Workflow).to receive(:find).with(workflow_id).and_return(fake_workflow_obj)
  end

  describe "with two CompileTurnJobs, one finished" do
    let(:job1) do
      fake_job(klass: SFL::Compiler::CompileTurnJob, finished: true,
               params: { turn_data: { name: "Alice" } })
    end
    let(:job2) do
      fake_job(klass: SFL::Compiler::CompileTurnJob, running: true,
               params: { turn_data: { name: "Bob" } })
    end
    let(:reduce_job) do
      fake_job(klass: SFL::Compiler::ReduceTurnsJob, finished: false)
    end
    let(:fake_workflow_obj) { fake_workflow(jobs: [job1, job2, reduce_job], status: :running) }

    it "returns running status with correct completed/total counts" do
      progress = described_class.new(workflow_id).poll

      expect(progress.status).to eq(:running)
      expect(progress.total).to eq(2)
      expect(progress.completed).to eq(1)
    end

    it "lists in-flight jobs by speaker label" do
      progress = described_class.new(workflow_id).poll

      expect(progress.running_jobs).to eq(["Bob"])
    end

    it "returns nil result when reduce job is not yet finished" do
      progress = described_class.new(workflow_id).poll

      expect(progress.result).to be_nil
    end
  end

  describe "with CompileSectionJobs" do
    let(:job1) do
      fake_job(klass: SFL::Compiler::CompileSectionJob, finished: true,
               params: { section_datum: { heading: "Introduction", file_id: "doc" } })
    end
    let(:job2) do
      fake_job(klass: SFL::Compiler::CompileSectionJob, running: true,
               params: { section_datum: { heading: nil, file_id: "doc" } })
    end
    let(:reduce_job) do
      fake_job(klass: SFL::Compiler::ReduceSectionsJob, finished: false)
    end
    let(:fake_workflow_obj) { fake_workflow(jobs: [job1, job2, reduce_job], status: :running) }

    it "counts section compile jobs correctly" do
      progress = described_class.new(workflow_id).poll

      expect(progress.total).to eq(2)
      expect(progress.completed).to eq(1)
    end

    it "falls back to file_id when heading is nil for running job label" do
      progress = described_class.new(workflow_id).poll

      expect(progress.running_jobs).to eq(["doc"])
    end
  end

  describe "when workflow is finished" do
    let(:result_payload) do
      { turn_count: 3, metadata: { speakers: ["Alice", "Bob"] }, insights: [] }
    end
    let(:compile_job) do
      fake_job(klass: SFL::Compiler::CompileTurnJob, finished: true,
               params: { turn_data: { name: "Alice" } })
    end
    let(:reduce_job) do
      fake_job(klass: SFL::Compiler::ReduceTurnsJob, finished: true, output: result_payload)
    end
    let(:fake_workflow_obj) { fake_workflow(jobs: [compile_job, reduce_job], status: :finished) }

    it "returns :finished status and the reduce job's output payload as result" do
      progress = described_class.new(workflow_id).poll

      expect(progress.status).to eq(:finished)
      expect(progress.result).to eq(result_payload)
    end

    it "reports zero running jobs and no failed jobs" do
      progress = described_class.new(workflow_id).poll

      expect(progress.running_jobs).to be_empty
      expect(progress.failed_jobs).to be_empty
      expect(progress.error).to be_nil
    end
  end

  describe "when a job has failed" do
    let(:failed_job) do
      fake_job(klass: SFL::Compiler::CompileTurnJob, failed: true,
               params: { turn_data: { name: "Bob" } })
    end
    let(:good_job) do
      fake_job(klass: SFL::Compiler::CompileTurnJob, finished: true,
               params: { turn_data: { name: "Alice" } })
    end
    let(:reduce_job) { fake_job(klass: SFL::Compiler::ReduceTurnsJob, finished: false) }
    let(:fake_workflow_obj) { fake_workflow(jobs: [good_job, failed_job, reduce_job], status: :failed) }

    it "returns :failed status and lists the failed class name" do
      progress = described_class.new(workflow_id).poll

      expect(progress.status).to eq(:failed)
      expect(progress.failed_jobs).to include("SFL::Compiler::CompileTurnJob")
      expect(progress.error).to eq("SFL::Compiler::CompileTurnJob")
    end
  end

  describe "caching behaviour" do
    let(:job) { fake_job(klass: SFL::Compiler::CompileTurnJob, finished: true, params: {}) }
    let(:reduce_job) { fake_job(klass: SFL::Compiler::ReduceTurnsJob, finished: false) }
    let(:fake_workflow_obj) { fake_workflow(jobs: [job, reduce_job], status: :running) }

    it "calls Gush::Workflow.find once and .reload on subsequent polls" do
      poller = described_class.new(workflow_id)

      poller.poll
      poller.poll

      expect(Gush::Workflow).to have_received(:find).once
      expect(fake_workflow_obj).to have_received(:reload).once
    end
  end
end
