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
      #   GET  /clauses                 → {clauses:[], total:, limit:, offset:}
      #   GET  /clauses/review-queue    → {clauses:[], total:, limit:, offset:} (flagged, with evidence)
      #   POST /clauses/:id/review      → AnnotationReview (sync) or {workflow_id:, status:} (async re_annotated)
      class Server
        CONTENT_JSON       = { "content-type" => "application/json" }.freeze
        WORKFLOW_STATUS_RE = /\A\/workflows\/(.+)\/status\z/.freeze
        CLAUSE_REVIEW_RE   = %r{\A/clauses/([^/]+)/review\z}.freeze

        # Dev-only allowlist: Vite's default port plus the 0.0.0.0-host
        # variant `npm run dev` binds to per this repo's own scripts.
        # No gem dependency (rack-cors isn't in the Gemfile) for three
        # headers — revisit if a production origin needs adding.
        CORS_ORIGINS = %w[http://localhost:3000 http://127.0.0.1:3000].freeze
        CORS_HEADERS = {
          "access-control-allow-methods" => "GET, POST, OPTIONS",
          "access-control-allow-headers" => "content-type",
        }.freeze

        # @param ctx [Bootstrap::Context] wired DB + DSPy config (no spaCy)
        def initialize(ctx)
          @ctx = ctx
        end

        def call(env)
          req = Rack::Request.new(env)
          origin = req.get_header("HTTP_ORIGIN")

          return preflight(origin) if req.request_method == "OPTIONS"

          status, headers, body = respond(req)
          [status, with_cors(headers, origin), body]
        end

        private

        def respond(req)
          dispatch(req)
        rescue ArgumentError => e
          json(400, { error: e.message })
        rescue => e
          warn "[ERROR] API #{e.class}: #{e.message}"
          json(500, { error: "Internal Server Error", message: e.message })
        end

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
          in ["GET", "/clauses/review-queue"]
            review_queue(req)
          in ["POST", CLAUSE_REVIEW_RE]
            clause_id = req.path_info.match(CLAUSE_REVIEW_RE)[1]
            review_clause(clause_id, req)
          in ["GET", "/clauses"]
            list_clauses(req)
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
                               .compile(text, document_id:, store:, embed:, resume: false, source_type: "api")
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
        # Body: {query:, filters?: {min_modality:, max_modality:, min_tenor:, max_tenor:, mood:, process_type:, source_type:}, limit?:}
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
                started_at:    unix_iso8601(j.started_at),
                finished_at:   unix_iso8601(j.finished_at) }
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

        # GET /clauses
        #
        # Query params: document_id, source_type, annotation_source, mood,
        # process_type, min_modality, max_modality, min_tenor, max_tenor,
        # limit (default 50), offset (default 0). Paginated scan for the
        # Corpus Browser — no query string, no ranking, unlike /retrieve.
        def list_clauses(req)
          p = req.params
          limit  = [p.fetch("limit", 50).to_i, 1].max
          offset = [p.fetch("offset", 0).to_i, 0].max
          filters = clauses_filters(p)

          result = ClauseRepository.new(@ctx.db).find_all(filters:, limit:, offset:)

          json(200, result.merge(limit:, offset:))
        end

        # GET /clauses/review-queue
        #
        # Query params: limit (default 50), offset (default 0). Same
        # pagination shape as GET /clauses, but the fixed "needs
        # attention" scope (ClauseRepository#review_queue) instead of
        # arbitrary filters, plus reasoning/reasoning_trace evidence
        # columns GET /clauses doesn't return.
        def review_queue(req)
          p = req.params
          limit  = [p.fetch("limit", 50).to_i, 1].max
          offset = [p.fetch("offset", 0).to_i, 0].max

          result = ClauseRepository.new(@ctx.db).review_queue(limit:, offset:)

          json(200, result.merge(limit:, offset:))
        end

        REVIEW_DECISIONS = %w[accepted rejected re_annotated].freeze

        # POST /clauses/:id/review
        #
        # Body: {decision: "accepted"|"rejected"|"re_annotated", reviewer?:, notes?:}
        #   accepted/rejected → synchronous: records the audit row, 200 with the AnnotationReview.
        #   re_annotated      → async, same job+poll shape as POST /pipeline/compile's
        #                       non-sync path: dispatches ReannotateClauseWorkflow, 202
        #                       {workflow_id:, status: "queued"}. The workflow itself
        #                       records the audit row once the recompile finishes.
        def review_clause(clause_id, req)
          body     = parse_body(req)
          decision = body["decision"]
          unless REVIEW_DECISIONS.include?(decision)
            raise ArgumentError, "decision must be one of #{REVIEW_DECISIONS.join(', ')}"
          end

          reviewer = body["reviewer"]
          notes    = body["notes"]
          return dispatch_reannotation(clause_id, reviewer, notes) if decision == "re_annotated"

          record_decision(clause_id, decision, reviewer, notes)
        end

        def dispatch_reannotation(clause_id, reviewer, notes)
          flow = ReannotateClauseWorkflow.create(clause_id:, reviewer:, notes:)
          flow.start!
          json(202, { workflow_id: flow.id, status: "queued" })
        end

        def record_decision(clause_id, decision, reviewer, notes)
          clause_repo = ClauseRepository.new(@ctx.db)
          found = clause_repo.find(clause_id)
          return json(404, { error: "clause not found", id: clause_id }) unless found

          original_source = found.dig(:interpersonal, :annotation_source) || "llm"
          review = clause_repo.record_review(
            clause_id:, decision:, original_annotation_source: original_source, reviewer:, notes:
          )
          json(200, Types.dump(review))
        end

        STRING_CLAUSE_FILTERS  = %w[document_id source_type annotation_source mood process_type].freeze
        NUMERIC_CLAUSE_FILTERS = %w[min_modality max_modality min_tenor max_tenor].freeze

        def clauses_filters(params)
          out = {}
          STRING_CLAUSE_FILTERS.each do |key|
            value = presence(params[key])
            out[key.to_sym] = value if value
          end
          NUMERIC_CLAUSE_FILTERS.each do |key|
            value = numeric(params[key])
            out[key.to_sym] = value if value
          end
          out
        end

        def presence(value)
          value.to_s.strip.empty? ? nil : value
        end

        def numeric(value)
          value.nil? || value.to_s.strip.empty? ? nil : value.to_f
        end

        def preflight(origin)
          [204, with_cors({}, origin), []]
        end

        def with_cors(headers, origin)
          return headers unless CORS_ORIGINS.include?(origin)

          headers.merge(CORS_HEADERS).merge("access-control-allow-origin" => origin)
        end

        # Gush::Job#started_at/#finished_at are Unix integers
        # (Time.now.to_i in gush's own #start!/#finish!), not Time
        # objects — Integer has no #iso8601.
        def unix_iso8601(unix_ts)
          unix_ts && Time.at(unix_ts).utc.iso8601
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
          out[:source_type]  = filters[:source_type].to_s  if filters[:source_type]
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
