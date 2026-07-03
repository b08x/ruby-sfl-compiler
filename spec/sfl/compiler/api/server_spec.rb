# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require_relative "../../../../lib/sfl/compiler/api"

RSpec.describe SFL::Compiler::API::Server do
  include Rack::Test::Methods

  let(:db)     { instance_double("Sequel::Database") }
  let(:config) { instance_double("SFL::Compiler::Configuration", spacy_model: "en_core_web_sm") }
  let(:ctx)    { SFL::Compiler::Bootstrap::Context.new(db:, config:) }

  def app
    described_class.new(ctx)
  end

  # ── GET /health ─────────────────────────────────────────────────────────────

  describe "GET /health" do
    it "returns 200 with status ok" do
      get "/health"
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body["status"]).to eq("ok")
      expect(body["version"]).to eq(SFL::Compiler::VERSION)
    end
  end

  # ── CORS ─────────────────────────────────────────────────────────────────────

  describe "CORS" do
    it "echoes the allowed dev origin on a normal request" do
      get "/health", {}, "HTTP_ORIGIN" => "http://localhost:3000"
      expect(last_response.headers["access-control-allow-origin"]).to eq("http://localhost:3000")
    end

    it "omits CORS headers for a non-allowlisted origin" do
      get "/health", {}, "HTTP_ORIGIN" => "https://evil.example"
      expect(last_response.headers).not_to have_key("access-control-allow-origin")
    end

    it "answers an OPTIONS preflight with 204 and the allowed methods/headers" do
      options "/retrieve", {}, "HTTP_ORIGIN" => "http://127.0.0.1:3000"
      expect(last_response.status).to eq(204)
      expect(last_response.headers["access-control-allow-origin"]).to eq("http://127.0.0.1:3000")
      expect(last_response.headers["access-control-allow-methods"]).to include("POST")
      expect(last_response.headers["access-control-allow-headers"]).to eq("content-type")
    end

    it "still 404s on unknown routes with CORS headers attached for an allowed origin" do
      get "/nonexistent", {}, "HTTP_ORIGIN" => "http://localhost:3000"
      expect(last_response.status).to eq(404)
      expect(last_response.headers["access-control-allow-origin"]).to eq("http://localhost:3000")
    end
  end

  # ── 404 catch-all ───────────────────────────────────────────────────────────

  describe "unknown route" do
    it "returns 404" do
      get "/nonexistent"
      expect(last_response.status).to eq(404)
      body = JSON.parse(last_response.body)
      expect(body["error"]).to eq("Not Found")
    end
  end

  # ── POST /pipeline/compile ───────────────────────────────────────────────────

  describe "POST /pipeline/compile" do
    context "when text is missing" do
      it "returns 400" do
        post "/pipeline/compile", JSON.dump({}), "CONTENT_TYPE" => "application/json"
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)["error"]).to match(/text is required/i)
      end
    end

    context "with sync: true" do
      let(:clause) do
        token = SFL::Compiler::Types::SyntacticToken.new(
          text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
          dep: "ROOT", head_index: -1, morphology: {}, index: 0
        )
        syntactic = SFL::Compiler::Types::SyntacticClause.new(
          id: "syn-1", text: "It works.", tokens: [token],
          root_index: 0, sentence_index: 0, document_id: "api-doc"
        )
        SFL::Compiler::Types::AnnotatedClause.new(
          id: SecureRandom.uuid, text: "It works.",
          syntactic: syntactic,
          ideational: SFL::Compiler::Types::IdeationalPayload.new(
            clause_id: "syn-1", process_type: "material",
            participants: [], circumstances: [], raw_transitivity: {}
          ),
          interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
            clause_id: "syn-1", mood: "declarative", modality_weight: 0.6,
            tenor: 0.5, speaker_attitude: nil, reasoning: nil,
            annotation_source: "llm"
          ),
          document_id: "api-doc", compiled_at: Time.now
        )
      end

      it "calls Pipeline#compile and returns AnnotatedClause array" do
        pipeline = instance_double(SFL::Compiler::Pipeline)
        allow(SFL::Compiler::Pipeline).to receive(:new).and_return(pipeline)
        allow(pipeline).to receive(:compile).and_return([clause])

        post "/pipeline/compile",
          JSON.dump(text: "It works.", sync: true),
          "CONTENT_TYPE" => "application/json"

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body).to be_an(Array)
        expect(body.first["text"]).to eq("It works.")
      end
    end

    context "with sync: false (async)" do
      it "creates a workflow and returns 202 with workflow_id" do
        flow = instance_double(SFL::Compiler::ConversationAnalysisWorkflow, id: "wf-123")
        allow(SFL::Compiler::ConversationAnalysisWorkflow).to receive(:create).and_return(flow)
        allow(flow).to receive(:start!)

        post "/pipeline/compile",
          JSON.dump(text: "It works.", sync: false),
          "CONTENT_TYPE" => "application/json"

        expect(last_response.status).to eq(202)
        body = JSON.parse(last_response.body)
        expect(body["workflow_id"]).to eq("wf-123")
        expect(body["status"]).to eq("queued")
        expect(flow).to have_received(:start!)
      end
    end
  end

  # ── POST /retrieve ───────────────────────────────────────────────────────────

  describe "POST /retrieve" do
    context "when query is missing" do
      it "returns 400" do
        post "/retrieve", JSON.dump({}), "CONTENT_TYPE" => "application/json"
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)["error"]).to match(/query is required/i)
      end
    end

    it "delegates to HybridRetriever and returns results" do
      retriever = instance_double(SFL::Compiler::HybridRetriever)
      allow(SFL::Compiler::HybridRetriever).to receive(:new).and_return(retriever)
      allow(retriever).to receive(:retrieve).and_return([{ clause_id: "c1", text: "Hello", score: 0.9 }])

      post "/retrieve",
        JSON.dump(query: "what is the main claim?", filters: { min_modality: 0.8 }, limit: 5),
        "CONTENT_TYPE" => "application/json"

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body["count"]).to eq(1)
      expect(body["results"].first["clause_id"]).to eq("c1")
      expect(retriever).to have_received(:retrieve)
        .with("what is the main claim?", limit: 5, filters: { min_modality: 0.8 })
    end

    it "strips unknown filter keys (whitelist enforcement)" do
      retriever = instance_double(SFL::Compiler::HybridRetriever)
      allow(SFL::Compiler::HybridRetriever).to receive(:new).and_return(retriever)
      allow(retriever).to receive(:retrieve).and_return([])

      post "/retrieve",
        JSON.dump(query: "test", filters: { min_modality: 0.5, injected_key: "evil" }),
        "CONTENT_TYPE" => "application/json"

      expect(last_response.status).to eq(200)
      expect(retriever).to have_received(:retrieve)
        .with("test", limit: 10, filters: { min_modality: 0.5 })
    end

    it "whitelists and forwards the source_type filter" do
      retriever = instance_double(SFL::Compiler::HybridRetriever)
      allow(SFL::Compiler::HybridRetriever).to receive(:new).and_return(retriever)
      allow(retriever).to receive(:retrieve).and_return([])

      post "/retrieve",
        JSON.dump(query: "test", filters: { source_type: "vault_markdown" }),
        "CONTENT_TYPE" => "application/json"

      expect(last_response.status).to eq(200)
      expect(retriever).to have_received(:retrieve)
        .with("test", limit: 10, filters: { source_type: "vault_markdown" })
    end
  end

  # ── POST /synthesize ─────────────────────────────────────────────────────────

  describe "POST /synthesize" do
    context "when query is missing" do
      it "returns 400" do
        post "/synthesize", JSON.dump({}), "CONTENT_TYPE" => "application/json"
        expect(last_response.status).to eq(400)
      end
    end

    it "delegates to ContextSynthesizer and returns serialized SynthesisResult" do
      result = SFL::Compiler::Types::SynthesisResult.new(
        query: "test?", answer: "The answer.", cited_clause_ids: ["c1"],
        clauses: [], retrieved_count: 3, confidence: 0.9
      )
      synthesizer = instance_double(SFL::Compiler::ContextSynthesizer)
      retriever   = instance_double(SFL::Compiler::HybridRetriever)
      clause_repo = instance_double(SFL::Compiler::ClauseRepository)

      allow(SFL::Compiler::HybridRetriever).to receive(:new).and_return(retriever)
      allow(SFL::Compiler::ClauseRepository).to receive(:new).and_return(clause_repo)
      allow(SFL::Compiler::ContextSynthesizer).to receive(:new).and_return(synthesizer)
      allow(synthesizer).to receive(:synthesize).and_return(result)

      post "/synthesize",
        JSON.dump(query: "test?"),
        "CONTENT_TYPE" => "application/json"

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body["answer"]).to eq("The answer.")
      expect(body["confidence"]).to eq(0.9)
    end
  end

  # ── POST /workflows ──────────────────────────────────────────────────────────

  describe "POST /workflows" do
    context "when jsonl_path is missing" do
      it "returns 400" do
        post "/workflows", JSON.dump({}), "CONTENT_TYPE" => "application/json"
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)["error"]).to match(/jsonl_path is required/i)
      end
    end

    context "when jsonl_path does not exist" do
      it "returns 400" do
        post "/workflows",
          JSON.dump(jsonl_path: "/nonexistent/path.jsonl"),
          "CONTENT_TYPE" => "application/json"
        expect(last_response.status).to eq(400)
        expect(JSON.parse(last_response.body)["error"]).to match(/file not found/i)
      end
    end

    context "with a valid file" do
      it "creates and starts workflow, returns 202 with workflow_id" do
        tmp = Tempfile.new(["test-", ".jsonl"])
        tmp.write(JSON.dump(speaker: "A", timestamp: Time.now.iso8601, message: "hello"))
        tmp.flush

        flow = instance_double(SFL::Compiler::ConversationAnalysisWorkflow, id: "wf-abc")
        allow(SFL::Compiler::ConversationAnalysisWorkflow).to receive(:create).and_return(flow)
        allow(flow).to receive(:start!)

        post "/workflows",
          JSON.dump(jsonl_path: tmp.path),
          "CONTENT_TYPE" => "application/json"

        expect(last_response.status).to eq(202)
        body = JSON.parse(last_response.body)
        expect(body["workflow_id"]).to eq("wf-abc")
        expect(body["status"]).to eq("running")
        expect(flow).to have_received(:start!)
      ensure
        tmp.close
        tmp.unlink
      end
    end
  end

  # ── GET /workflows/:id/status ─────────────────────────────────────────────────

  describe "GET /workflows/:id/status" do
    context "when workflow does not exist" do
      it "returns 404" do
        allow(Gush::Workflow).to receive(:find).and_raise(Gush::WorkflowNotFound)
        get "/workflows/unknown-id/status"
        expect(last_response.status).to eq(404)
        expect(JSON.parse(last_response.body)["error"]).to match(/workflow not found/i)
      end
    end

    context "when workflow is running" do
      it "returns status and job list without output" do
        t = Time.at(1_750_000_000)
        job = instance_double("Gush::Job",
          name:        "SFL::Compiler::CompileTurnJob|abc",
          failed?:     false,
          finished?:   false,
          running?:    true,
          started_at:  t,
          finished_at: nil)
        allow(job).to receive(:is_a?).with(SFL::Compiler::ReduceTurnsJob).and_return(false)
        allow(t).to receive(:iso8601).and_return("2026-07-02T00:00:00Z")

        flow = instance_double("Gush::Workflow",
          id:        "wf-running",
          status:    :running,
          finished?: false,
          jobs:      [job])
        allow(Gush::Workflow).to receive(:find).with("wf-running").and_return(flow)
        allow(flow).to receive(:reload).and_return(flow)

        get "/workflows/wf-running/status"

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["status"]).to eq("running")
        expect(body["jobs"].size).to eq(1)
        expect(body).not_to have_key("output")
      end
    end

    context "when workflow is finished" do
      it "returns status, jobs, and output from ReduceTurnsJob" do
        output_data = { "metadata" => { "turn_count" => 1 }, "turns" => [] }
        t0 = Time.at(0)
        t1 = Time.at(1)
        allow(t0).to receive(:iso8601).and_return("1970-01-01T00:00:00Z")
        allow(t1).to receive(:iso8601).and_return("1970-01-01T00:00:01Z")

        reduce_job = instance_double(SFL::Compiler::ReduceTurnsJob,
          name:           "SFL::Compiler::ReduceTurnsJob|xyz",
          failed?:        false,
          finished?:      true,
          running?:       false,
          output_payload: output_data,
          started_at:     t0,
          finished_at:    t1)
        allow(reduce_job).to receive(:is_a?).with(SFL::Compiler::ReduceTurnsJob).and_return(true)

        flow = instance_double("Gush::Workflow",
          id:        "wf-done",
          status:    :finished,
          finished?: true,
          jobs:      [reduce_job])
        allow(Gush::Workflow).to receive(:find).with("wf-done").and_return(flow)
        allow(flow).to receive(:reload).and_return(flow)

        get "/workflows/wf-done/status"

        expect(last_response.status).to eq(200)
        body = JSON.parse(last_response.body)
        expect(body["status"]).to eq("finished")
        expect(body["output"]).to eq(output_data)
      end
    end
  end

  # ── Bad JSON body ─────────────────────────────────────────────────────────────

  describe "invalid JSON body" do
    it "returns 400 for malformed JSON" do
      post "/retrieve", "{bad json", "CONTENT_TYPE" => "application/json"
      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)["error"]).to match(/Invalid JSON/i)
    end
  end
end
