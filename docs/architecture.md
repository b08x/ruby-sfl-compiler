# Architecture

The sfl-compiler follows a **layered pipeline** with strict separation between syntactic extraction (Pass 1), semantic annotation (Pass 2), and analysis. Today's additions introduce **parallel execution** (Gush workflows), **cross-document reasoning** (CrossDocumentGraph), and **pre-flight observability** (LangfuseReachability).

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
| `TenorTracker` | Formality shift detection (mutates in-place) |
| `SpeakerProfiler` | Per-speaker linguistic patterns |
| `CohesionAnalyzer` | Repetition, conjunction, pronoun density |
| `TopicModeler` | LDA/HDP topic clustering |
| `CorrelationAnalyzer` | Process type × tenor/modality correlation |
| `NarrativeGenerator` | LLM prose from structured analysis |
| `QuestionGraph` | Gödel-encoded dependency DAG |
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
└──────────────────┴────────────────┴───────────────────────────────┘
```

---

## Gödel Numbering in QuestionGraph

```
  Question: "Does modality hold across doc types?"
  Dependencies: [doc0.modality, doc1.modality]
       │
       ▼
  Assign primes in topological order:
    doc0.modality → 2 (axiomatic)
    doc1.modality → 3 (axiomatic)
    this_question  → 5 × (2 × 3) = 30  (derived)
       │
       ▼
  gödel_number = 2 × 3 × 30 = 180
  factor(180) = {2=>1, 3=>1, 5→2}  ← verifies encoding
  decode(180) → all questions whose value divides 180
  consistent? → decode.keys.sort == questions.keys.sort
```

---

## Cross-Document Reasoning

```
  Sprint A (doc0)          Sprint B (doc1)
  ┌──────────────┐         ┌──────────────┐
  │ QuestionGraph│         │ QuestionGraph│
  │  modality=2  │         │  modality=3  │
  │  tenor=5     │         │  tenor=7     │
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

## Design Philosophy

> **"Developer happiness, expressiveness, and craft"** — the project mirrors Ruby's own DNA. The two-pass architecture separates what is deterministic (syntax) from what requires judgment (semantics). The parallel execution model respects process isolation. The analysis layer treats data quality as a first-class concern, not an afterthought.
