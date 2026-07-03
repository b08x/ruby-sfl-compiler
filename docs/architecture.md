# Architecture

The sfl-compiler follows a **layered pipeline** with strict separation between syntactic extraction (Pass 1), semantic annotation (Pass 2), and analysis. The architecture supports **parallel execution** (Gush workflows), **cross-document reasoning** (CrossDocumentGraph), **knowledge base analysis** (KnowledgeBaseAnalyzer), and **pre-flight observability** (LangfuseReachability).

---

## System Overview

```
                          ┌─────────────────────────────────────┐
                          │          Entry Points               │
                          │  exe/sfl-analyze  │  TUI │  Chat    │
                          └────────┬──────────┴──────┴────┬─────┘
                                   │                      │
                          ┌────────┴────────┐    ┌───────┴────────┐
                          │    Bootstrap    │    │  Bubbletea TUI │
                          │ (ENV → config) │    │  (interactive) │
                          └────────┬────────┘    └────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
     ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
     │   Workflow     │  │   Workflow     │  │   Workflow     │
     │ (parallel Gush)│  │ (parallel Gush)│  │  (in-process)  │
     │                │  │                │  │                │
     │ Conversation   │  │    Sprint      │  │  Documentation │
     │ Analysis       │  │  (4-stage)     │  │  Analysis      │
     └───────┬────────┘  └───────┬────────┘  └───────┬────────┘
             │                   │                   │
             ▼                   ▼                   ▼
     ┌─────────────────────────────────────────────────────────┐
     │                    Pipeline Core                         │
     │  Pass 1 (spaCy) → GC → Pass 2 (LLM) → Store → Embed   │
     └─────────────────────────────────────────────────────────┘
             │                                       │
             ▼                                       ▼
     ┌────────────────┐                    ┌────────────────┐
     │   Analysis     │                    │   Retrieval    │
     │  Layer         │                    │   Layer        │
     │                │                    │                │
     │ • TenorTracker │                    │ • Embedder     │
     │ • SpeakerProf  │                    │ • HybridRetr.  │
     │ • Cohesion     │                    │   (RRF)        │
     │ • TopicModel   │                    └────────────────┘
     │ • Correlation  │
     │ • Narrative    │
     │ • QuestionGraph│
     │ • CrossDocGraph│
     │ • KBAnalyzer   │
     └────────────────┘
```

---

## Execution Models

### 1. Parallel Conversation Workflow (Gush + Sidekiq)

```
  CLI ──► ConversationAnalysisWorkflow.configure()
              │
              ├──[topics≥3]──► TopicModelJob ─────────────────────┐
              │                    (fit LDA/HDP)                  │
              │                                                    │
              ├──► CompileTurnJob #1 ──┐                         │
              ├──► CompileTurnJob #2 ──┤  (parallel workers)     ├──► ReduceTurnsJob
              ├──► CompileTurnJob #3 ──┤  (own Python interp.)   │    (cross-turn aggreg.)
              └──► CompileTurnJob #N ──┘    ▲                    │
                                             │                    │
                              topic_job ──────┘ (dependency)      │
                                                            ┌─────┴──────┐
                                                            │AnalysisResult│
                                                            └─────────────┘
```

**Why Gush?** Each `CompileTurnJob` runs in its own Sidekiq worker process with its own Python interpreter. Pass 1's PyCall/spaCy is **not shared across threads** — the old Bubbletea `--live` TUI deadlocked because of this. Gush gives true process isolation.

### 2. Sprint Workflow (4-Stage Sequential)

```
  SprintWorkflow.configure(domain_payload)
       │
       ├──► SprintRoleJob(:achilles) ──► proposes
       │
       ├──► SprintRoleJob(:tortoise) ──► challenges (after achilles)
       │
       ├──► CrabConstraintJob ──► pins invariants (after tortoise)
       │
       └──► SprintRoleJob(:genie) ──► synthesizes (after crab)
```

### 3. In-Process Documentation Pipeline

```
  CLI ──► DocumentationAnalyzer ──► Pipeline (synchronous)
                                            │
                                            ├── Pass 1 → Ideational
                                            ├── Pass 2 → Interpersonal + Textual
                                            └── Store + Embed
```

### 4. Knowledge Base Analysis Pipeline

```
  CLI ──► KnowledgeBaseAnalyzer ──► Pipeline (synchronous)
                                            │
                                            ├── collect_files (.md, .pdf, .png)
                                            ├── load_sections (MarkdownLoader/PdfLoader/ImageLoader)
                                            ├── compile_artifact (per section)
                                            │     ├── Pipeline.compile → AnnotatedClause[]
                                            │     ├── ContentTypeClassifier.classify
                                            │     └── QualityScorer.score
                                            ├── MigrationAssessor.assess
                                            └── KBReportWriter.write (CSV, JSON, Markdown)
```

### 5. Falcon API Server (Concurrent, Fiber-Based)

```
  ConvoWorkbench (React) ──► Falcon (Async) ──► Server#respond
                                                      │
                                    ┌─────────────────┼─────────────────┐
                                    ▼                 ▼                 ▼
                          POST /synthesize   POST /workflows    GET /clauses
                          (ContextSynthesizer) (Gush dispatch)  (ClauseRepository)
```

Falcon serves concurrent requests as `Async` fibers cooperatively scheduled
within a single OS thread per worker process — not one thread per request.
`Database.connect` (see [Database](modules/database.md)) selects a
fiber-safe connection pool (`pool_class: :timed_queue` + the
`fiber_concurrency` extension) specifically because of this: a
thread-keyed pool hands two concurrent fibers the same connection, and
their queries interleave on one socket. Any code path reachable from more
than one Falcon route concurrently (e.g. two `/synthesize` calls fired in
parallel, as the ConvoWorkbench Safe RAG Hypothesis Validator does by
design) depends on this pool selection being correct.

---

## Layer Responsibilities

### Input Layer

| Component | Responsibility |
|-----------|---------------|
| `CLI` | Argv parsing, exit codes — pure function `.parse` |
| `MarkdownLoader` | Chunk + segment markdown/PDF into sections |
| `Bootstrap` | ENV → Configuration + DB + DSPy + Observability |
| `LangfuseReachability` | Pre-flight TCP check; prompts continue/cancel |

### Extraction Layer (Pass 1)

| Component | Responsibility |
|-----------|---------------|
| `PassOneEngine` | spaCy tokenization, POS, dependency parsing |
| `IdeationalExtractor` | Rule-based transitivity classification |

### Annotation Layer (Pass 2)

| Component | Responsibility |
|-----------|---------------|
| `PassTwoEngine` | LLM interpersonal + textual annotation |
| `SFLAnnotator` | Single-clause DSPy ChainOfThought |
| `SFLBatchAnnotator` | Batched multi-clause DSPy |
| `ThemeRhemeExtractor` | Experimental theme/rheme via LLM |

### Analysis Layer

| Component | Responsibility |
|-----------|---------------|
| `ConversationAnalyzer` | Turn-level aggregation |
| `KnowledgeBaseAnalyzer` | Documentation analysis pipeline (content typing, quality scoring, migration assessment) |
| `TenorTracker` | Formality shift detection (mutates in-place) |
| `SpeakerProfiler` | Per-speaker linguistic patterns |
| `CohesionAnalyzer` | Repetition, conjunction, pronoun density |
| `TopicModeler` | LDA/HDP topic clustering |
| `CorrelationAnalyzer` | Process type × tenor/modality correlation |
| `NarrativeGenerator` | LLM prose from structured analysis |
| `QuestionGraph` | Adjacency-list dependency DAG; `roots`/`leaves`/`ancestors`/`descendants`/`reachable?` |
| `CrossDocumentGraph` | Multi-document question merging |

### Storage Layer

| Component | Responsibility |
|-----------|---------------|
| `ClauseRepository` | CRUD with payload separation |
| `EmbeddingRepository` | pgvector encode/decode/store |
| `PipelineCache` | Disk-based JSON cache (resume) |
| `Database` | Connection + schema + migrations |

### Retrieval Layer

| Component | Responsibility |
|-----------|---------------|
| `Embedder` | Text → 768-dim vector (Ollama embeddinggemma) |
| `HybridRetriever` | RRF fusion of semantic + keyword + scalar filters |
| `ContextSynthesizer` | Retrieval → cited, stance-annotated LLM answer synthesis |

### Orchestration Layer

| Component | Responsibility |
|-----------|---------------|
| `Pipeline` | Pass 1 → GC → Pass 2 → Store → Embed |
| `ConversationAnalysisWorkflow` | Gush: fan-out CompileTurnJob, fan-in ReduceTurnsJob |
| `SprintWorkflow` | Gush: Achilles → Tortoise → Crab → Genie |

### Jobs Layer

| Component | Responsibility |
|-----------|---------------|
| `CompileTurnJob` | Per-turn Pass 1 + Pass 2 (Gush job) |
| `ReduceTurnsJob` | Cross-turn aggregation (Gush job) |
| `TopicModelJob` | Topic modeling pre-pass (Gush job) |
| `SprintRoleJob` | Generic Achilles/Tortoise/Genie role (Gush job) |
| `CrabConstraintJob` | Rule-based invariant pinning (Gush job) |
| `KnowledgeBaseCompileJob` | Per-section KB analysis (in-process, used by KB analyzer) |

---

## Critical Dependencies

```
┌───────────────────────────────────────────────────────────────────┐
│                    Failure Mode Map                                │
├──────────────────┬────────────────┬───────────────────────────────┤
│ Dependency       │ Failure Impact │ Mitigation                    │
├──────────────────┼────────────────┼───────────────────────────────┤
│ LLM (Ollama/    │ Pass 2 fails   │ Circuit breaker → 3 retries  │
│ OpenAI/etc)      │                │ → fallback defaults (0.5)     │
│                  │                │ → annotation_source="fallback"│
├──────────────────┼────────────────┼───────────────────────────────┤
│ spaCy            │ Pass 1 fails   │ PassOneError raised →         │
│                  │                │ pipeline aborts cleanly       │
├──────────────────┼────────────────┼───────────────────────────────┤
│ PostgreSQL       │ No storage     │ Sequel::DatabaseError →       │
│                  │                │ clear error message           │
├──────────────────┼────────────────┼───────────────────────────────┤
│ pgvector         │ No embeddings  │ Falls back to keyword-only    │
│                  │                │ retrieval; warning logged     │
├──────────────────┼────────────────┼───────────────────────────────┤
│ Redis (Gush)      │ No parallel    │ Workflow cannot run;          │
│                  │ execution      │ falls back to sequential      │
├──────────────────┼────────────────┼───────────────────────────────┤
│ Langfuse         │ No tracing     │ Pre-flight check prompts;     │
│                  │                │ --disable-tracing always works│
├──────────────────┼────────────────┼───────────────────────────────┤
│ Kreuzberg        │ No file I/O    │ KB analyzer fails; raises     │
│ (PDF/image)      │                │ DocumentLoadError             │
└──────────────────┴────────────────┴───────────────────────────────┘
```

---

## QuestionGraph: Dependency Tracking

### Current Implementation — Adjacency List (In-Memory)

`QuestionGraph` (`lib/sfl/compiler/question_graph.rb`) tracks question
dependencies across multi-agent reasoning sprints as a pair of adjacency
lists — forward (`children`: who depends on a given node) and reverse
(`parents`: what a given node depends on) — built in one pass at
construction time.

```
  questions = [
    { id: :modality,           dependencies: [] },
    { id: :data_quality,       dependencies: [] },
    { id: :tenor_consistency,  dependencies: [] },
    { id: :overall_confidence, dependencies: [:modality, :data_quality, :tenor_consistency] },
  ]

  graph = QuestionGraph.new(questions)
  graph.roots     #=> [:modality, :data_quality, :tenor_consistency]
  graph.leaves    #=> [:overall_confidence]
  graph.depth(:overall_confidence)          #=> 1
  graph.ancestors(:overall_confidence)      #=> [:modality, :data_quality, :tenor_consistency]
  graph.reachable?(from: :modality, to: :overall_confidence) #=> true
```

Topological ordering uses Kahn's algorithm. Construction raises
`QuestionGraphError` on cycles or unresolvable dependency ids, both of
which prevent the graph from being built.

### Future: Persistent Graph Storage

The in-memory adjacency list has no overflow ceiling and handles sprint-scale
graphs (typically < 20 nodes) without issue. Future enhancements may add
PostgreSQL persistence for cross-session and cross-document reasoning:

- **Adjacency list table** — `question_edges(parent_id, child_id, depth)` with
  recursive CTEs for reachability and topological ordering.
- **Postgres Ltree** — path-encoded label strings (`doc0.modality.confidence`)
  enabling subtree queries and depth constraints via native GiST indexing.

See `ROADMAP.md` for future design details.

---

## Cross-Document Reasoning

```
  Sprint A (doc0)          Sprint B (doc1)
  ┌──────────────┐         ┌──────────────┐
  │ QuestionGraph│         │ QuestionGraph│
  │  :modality   │         │  :modality   │
  │  :tenor      │         │  :tenor      │
  └──────┬───────┘         └──────┬───────┘
         │                        │
         └──────────┬─────────────┘
                    ▼
         ┌─────────────────────┐
         │ CrossDocumentGraph  │
         │ .aggregate([A, B])  │
         │                     │
         │ • namespace ids     │
         │ • detect new        │
         │   derived questions │
         │ • reconcile numeric │
         │   findings (≥0.3    │
         │   threshold)        │
         └─────────────────────┘
```

---

## Observability Flow

```
  exe/sfl-analyze
       │
       ├── Dotenv.load (before require "sfl-compiler")
       │
       ├── LangfuseReachability.decide(env:, tty:)
       │       │
       │       ├── keys missing → :traced (no tracing)
       │       ├── reachable    → :traced (proceed)
       │       ├── unreachable + tty → prompt → :skip or :cancel
       │       └── unreachable + non-tty → :skip
       │
       ├── require "sfl-compiler"
       │       │
       │       └── dspy-o11y-langfuse checks ENV (one-shot)
       │               │
       │               ├── keys present + reachable → tracing ON
       │               └── keys absent or unset → tracing OFF
       │
       └── Journald::Logger on every operation (correlation_id)
```

---

## Trace Paths

The codebase provides detailed trace paths for navigating the analysis pipelines. These are documented in the `docs/modules/` directory with `file:line` references for IDE navigation.

### Conversation Analysis (In-Process)

```
cli.rb:218  CLI.parse(:conversation)
  └─► conversation_analyzer.rb:61  ConversationAnalyzer.analyze
       ├─► conversation_analyzer.rb:119  build_result
       └─► pipeline.rb:45  Pipeline.compile
            ├─► pipeline.rb:78  pass_one (spaCy)
            └─► pipeline.rb:112 pass_two (LLM)
```

### Knowledge Base Analysis

```
cli.rb:276  CLI.parse(:documentation)
  └─► knowledge_base_analyzer.rb:47  KnowledgeBaseAnalyzer.analyze
       ├─► knowledge_base_analyzer.rb:99  load_all_sections
       ├─► knowledge_base_analyzer.rb:139 compile_artifact
       │    ├─► pipeline.rb:45  Pipeline.compile
       │    ├─► content_type_classifier.rb:25  classify
       │    └─► quality_scorer.rb:33  score
       ├─► migration_assessor.rb:42  assess
       └─► kb_report_writer.rb:19  write
```

### Parallel Conversation Workflow (Gush)

```
cli.rb:218  CLI.parse(:conversation)
  └─► conversation_analysis_workflow.rb:24  configure
       ├─► compile_turn_job.rb:21  perform (N workers)
       │    ├─► pass_one_engine.rb:42  process
       │    └─► pass_two_engine.rb:65  process
       ├─► topic_model_job.rb:18  perform
       └─► reduce_turns_job.rb:22  perform
            └─► conversation_analyzer.rb:61  build_result
```

### Falcon API: Synthesize (Concurrent)

```
api/server.rb:139        synthesize
  └─► context_synthesizer.rb:35   ContextSynthesizer.synthesize
       ├─► hybrid_retriever.rb:38  retrieve
       ├─► clause_repository.rb:141 find (per retrieved row)
       └─► context_synthesizer.rb:66  synthesize_from_citable
            └─► SFLSynthesizer#call → DSPy::ChainOfThought
```

Reachable concurrently — see [Execution Model 5](#5-falcon-api-server-concurrent-fiber-based).

See `docs/data-flow.md` for complete trace path documentation.

---

## Design Philosophy

> **"Developer happiness, expressiveness, and craft"** — the project mirrors Ruby's own DNA. The two-pass architecture separates what is deterministic (syntax) from what requires judgment (semantics). The parallel execution model respects process isolation. The analysis layer treats data quality as a first-class concern, not an afterthought.
