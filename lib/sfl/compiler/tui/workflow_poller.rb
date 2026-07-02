# frozen_string_literal: true

require "redis"
require "json"

module SFL
  module Compiler
    module TUI
      # Reads Gush workflow state from Redis and translates it into a plain
      # Progress struct that BatchApp's update loop can consume on each tick.
      #
      # Never touches Pipeline, PassOneEngine, spaCy, or PyCall. The actual
      # SFL analysis runs in separate Sidekiq OS processes; this class only
      # reads the Redis state they write. Calling #poll from Bubbletea's main
      # thread is safe because redis-client uses a thread-safe connection pool.
      class WorkflowPoller
        # Plain value object returned by #poll on every tick.
        # All fields are read-only after construction.
        Progress = Struct.new(
          :workflow_id,
          :status,          # Symbol — :pending/:running/:finished/:failed/:stopped
          :total,           # Integer — number of compile-stage jobs
          :completed,       # Integer — compile jobs that have finished
          :running_jobs,    # Array<String> — human labels for in-flight jobs
          :failed_jobs,     # Array<String> — class names of any failed jobs
          :result,          # Hash? — reduce job's output_payload; non-nil only when :finished
          :error,           # String? — first failed job class name; non-nil only when :failed
          :chunk_progress,  # Hash<String,Hash> — {label => {chunks_done:, chunks_total:}}
          keyword_init: true
        )

        # Compile-stage job class names — the set of job types that represent
        # one unit of analysis work (one turn or one section). The reduce/meta
        # jobs are excluded from progress counts.
        COMPILE_JOB_CLASSES = %w[
          SFL::Compiler::CompileTurnJob
          SFL::Compiler::CompileSectionJob
        ].freeze

        REDUCE_JOB_CLASSES = %w[
          SFL::Compiler::ReduceTurnsJob
          SFL::Compiler::ReduceSectionsJob
        ].freeze

        # @param workflow_id [String] Gush workflow UUID returned by
        #   ConversationAnalysisWorkflow.create(path).id
        def initialize(workflow_id)
          @workflow_id = workflow_id
          @workflow = nil
        end

        # Reloads workflow state from Redis and returns a Progress struct.
        # First call fetches via Gush::Workflow.find; subsequent calls use
        # the cached reference with .reload (avoids reconstructing the object
        # graph from scratch on every tick).
        #
        # @return [Progress]
        def poll
          reload_workflow
          build_progress
        end

        private def reload_workflow
          if @workflow
            @workflow.reload
          else
            @workflow = Gush::Workflow.find(@workflow_id)
          end
        end

        private def build_progress
          compile_jobs = @workflow.jobs.select { |j| COMPILE_JOB_CLASSES.include?(j.klass.to_s) }
          reduce_job   = @workflow.jobs.find   { |j| REDUCE_JOB_CLASSES.include?(j.klass.to_s) }

          completed    = compile_jobs.count(&:finished?)
          running_now  = compile_jobs.select(&:running?)
          failed_now   = @workflow.jobs.select(&:failed?).map { |j| j.klass.to_s }
          chunk_prog   = read_chunk_progress(running_now)

          Progress.new(
            workflow_id:    @workflow_id,
            status:         @workflow.status,
            total:          compile_jobs.size,
            completed:,
            running_jobs:   running_now.map { |j| job_label(j) },
            failed_jobs:    failed_now,
            result:         reduce_job&.finished? ? reduce_job.output_payload : nil,
            error:          failed_now.first,
            chunk_progress: chunk_prog,
          )
        end

        private def read_chunk_progress(running_jobs)
          running_jobs.each_with_object({}) do |job, h|
            key = "sfl:chunk:#{@workflow_id}:#{job.name}"
            raw = redis.get(key)
            next unless raw
            h[job_label(job)] = JSON.parse(raw, symbolize_names: true)
          rescue StandardError
            # Redis read failure is non-fatal — omit chunk progress for this job
          end
        end

        private def redis
          @redis ||= Redis.new(url: Gush.configuration.redis_url)
        end

        # Best-effort human label extracted from the job's params. Falls back
        # to the class name so the UI never shows a raw UUID.
        #
        # CompileTurnJob:    params[:turn_data][:name]
        # CompileSectionJob: params[:section_datum][:heading] || [:file_id]
        private def job_label(job)
          p = job.params || {}
          p.dig(:turn_data, :name) ||
            p.dig(:section_datum, :heading) ||
            p.dig(:section_datum, :file_id) ||
            job.klass.to_s
        end
      end
    end
  end
end
