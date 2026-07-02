# frozen_string_literal: true

require "json"
require "rack"

module SFL
  module Compiler
    module API
      # Rack application for the SFL HTTP API.
      #
      # Entry point: config.ru → `run SFL::Compiler::API::Server.new(ctx)`
      #
      # Routes:
      #   GET  /health                  → {status: "ok", version:}
      #   POST /pipeline/compile        → AnnotatedClause[] (sync) or {workflow_id:, status:} (async)
      #   POST /retrieve                → {results: Clause[], count:}
      #   POST /synthesize              → SynthesisResult
      #   POST /workflows               → {workflow_id:, status: "running"}
      #   GET  /workflows/:id/status    → {status:, jobs:[], output?:}
      class Server
        CONTENT_JSON       = { "content-type" => "application/json" }.freeze
        WORKFLOW_STATUS_RE = /\A\/workflows\/(.+)\/status\z/.freeze

        # @param ctx [Bootstrap::Context] wired DB + DSPy config (no spaCy)
        def initialize(ctx)
          @ctx = ctx
        end

        def call(env)
          req = Rack::Request.new(env)
          dispatch(req)
        rescue ArgumentError => e
          json(400, { error: e.message })
        rescue => e
          warn "[ERROR] API #{e.class}: #{e.message}"
          json(500, { error: "Internal Server Error", message: e.message })
        end

        private

        def dispatch(req)
          case [req.request_method, req.path_info]
          in ["GET", "/health"]
            json(200, { status: "ok", version: SFL::Compiler::VERSION })
          in ["POST", "/pipeline/compile"]
            compile_pipeline(req)
          in ["POST", "/retrieve"]
            retrieve(req)
          in ["POST", "/synthesize"]
            synthesize(req)
          in ["POST", "/workflows"]
            create_workflow(req)
          in ["GET", WORKFLOW_STATUS_RE]
            wf_id = req.path_info.match(WORKFLOW_STATUS_RE)[1]
            workflow_status(wf_id)
          else
            json(404, { error: "Not Found", path: req.path_info })
          end
        end

        # POST /pipeline/compile
        #
        # Body: {text:, document_id:, store:, embed:, sync:}
        #   sync: true  → compile inline → AnnotatedClause[] (PyCall runs in this process/fiber)
        #   sync: false → dispatch via ConversationAnalysisWorkflow → {workflow_id:, status: "queued"}
        def compile_pipeline(req)
          body = parse_body(req)
          text = body["text"]
          raise ArgumentError, "text is required" if text.nil? || text.to_s.strip.empty?

          document_id = body["document_id"] || "api-#{SecureRandom.uuid}"
          store       = body.fetch("store", false)
          embed       = body.fetch("embed", false)
          sync        = body.fetch("sync", false)

          if sync
            clauses = Pipeline.new(db: @ctx.db, spacy_model: @ctx.config.spacy_model)
                               .compile(text, document_id:, store:, embed:, resume: false)
            json(200, clauses.map { |c| Types.dump(c) })
          else
            # Write a single-turn JSONL and run it through ConversationAnalysisWorkflow
            # so PyCall only executes inside a Sidekiq worker process.
            tmp_path = "/tmp/sfl-api-compile-#{SecureRandom.uuid}.jsonl"
            File.write(tmp_path, JSON.dump(speaker: "api", timestamp: Time.now.iso8601, message: text))
            flow = ConversationAnalysisWorkflow.create(tmp_path, topics: nil)
            flow.start!
            json(202, { workflow_id: flow.id, status: "queued" })
          end
        end

        # POST /retrieve
        #
        # Body: {query:, filters?: {min_modality:, max_modality:, min_tenor:, max_tenor:, mood:, process_type:}, limit?:}
        def retrieve(req)
          body  = parse_body(req)
          query = body["query"]
          raise ArgumentError, "query is required" if query.nil? || query.to_s.strip.empty?

          filters = validate_filters(symbolize_keys(body.fetch("filters", {})))
          limit   = [body.fetch("limit", 10).to_i, 1].max

          results = HybridRetriever.new(db: @ctx.db).retrieve(query, limit:, filters:)
          json(200, { query:, results:, count: results.size })
        end

        # POST /synthesize
        #
        # Body: {query:, filters?:, limit?:, include_fallback?:}
        def synthesize(req)
          body  = parse_body(req)
          query = body["query"]
          raise ArgumentError, "query is required" if query.nil? || query.to_s.strip.empty?

          filters          = validate_filters(symbolize_keys(body.fetch("filters", {})))
          limit            = [body.fetch("limit", 10).to_i, 1].max
          include_fallback = body.fetch("include_fallback", false)

          retriever   = HybridRetriever.new(db: @ctx.db)
          clause_repo = ClauseRepository.new(@ctx.db)
          result      = ContextSynthesizer.new(retriever:, clause_repo:).synthesize(
            query, filters:, limit:, include_fallback:
          )
          json(200, Types.dump(result))
        end

        # POST /workflows
        #
        # Body: {jsonl_path:}
        def create_workflow(req)
          body       = parse_body(req)
          jsonl_path = body["jsonl_path"]
          raise ArgumentError, "jsonl_path is required" if jsonl_path.nil? || jsonl_path.to_s.strip.empty?
          raise ArgumentError, "file not found: #{jsonl_path}" unless File.exist?(jsonl_path)

          flow = ConversationAnalysisWorkflow.create(jsonl_path, topics: nil)
          flow.start!
          json(202, { workflow_id: flow.id, status: "running" })
        end

        # GET /workflows/:id/status
        def workflow_status(wf_id)
          flow = Gush::Workflow.find(wf_id)
          flow.reload

          payload = {
            workflow_id: flow.id,
            status:      flow.status.to_s,
            jobs:        flow.jobs.map { |j|
              { name:          j.name,
                status:        job_status(j),
                started_at:    j.started_at&.iso8601,
                finished_at:   j.finished_at&.iso8601 }
            }
          }

          if flow.finished?
            reduce_job = flow.jobs.find { |j| j.is_a?(ReduceTurnsJob) }
            payload[:output] = reduce_job&.output_payload
          end

          json(200, payload)
        rescue Gush::WorkflowNotFound
          json(404, { error: "workflow not found", id: wf_id })
        end

        def job_status(job)
          if job.failed?     then "failed"
          elsif job.finished? then "finished"
          elsif job.running?  then "running"
          else "pending"
          end
        end

        def parse_body(req)
          raw = req.body.read
          return {} if raw.nil? || raw.empty?

          JSON.parse(raw)
        rescue JSON::ParserError => e
          raise ArgumentError, "Invalid JSON body: #{e.message}"
        end

        def symbolize_keys(hash)
          hash.transform_keys(&:to_sym)
        end

        # Whitelist and coerce filter params — prevents arbitrary hash keys
        # from reaching HybridRetriever's apply_filters.
        def validate_filters(filters)
          out = {}
          out[:mood]         = filters[:mood].to_s         if filters[:mood]
          out[:process_type] = filters[:process_type].to_s if filters[:process_type]
          out[:min_modality] = filters[:min_modality].to_f if filters.key?(:min_modality)
          out[:max_modality] = filters[:max_modality].to_f if filters.key?(:max_modality)
          out[:min_tenor]    = filters[:min_tenor].to_f    if filters.key?(:min_tenor)
          out[:max_tenor]    = filters[:max_tenor].to_f    if filters.key?(:max_tenor)
          out
        end

        def json(status, body)
          [status, CONTENT_JSON, [JSON.dump(body)]]
        end
      end
    end
  end
end
