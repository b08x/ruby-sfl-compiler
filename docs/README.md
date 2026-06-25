# SFL-Compiler

> **Conversation and documentation text → SFL analysis** through a two-pass pipeline (spaCy + LLM) with Gödel-encoded question graphs and parallel Gush workflows.

---

## At a Glance

```
┌─────────────────────────────────────────────────────────────────────┐
│                         sfl-analyze CLI                              │
├──────────────┬──────────────┬──────────────┬────────────────────────┤
│ conversation │ documentation│   context    │         tui            │
└──────┬───────┴──────┬───────┴──────┬───────┴──────────┬─────────────┘
       │              │              │                    │
       ▼              ▼              ▼                    ▼
┌──────────────────────────────────────────┐    ┌──────────────────┐
│        Gush Workflow (parallel)          │    │  Bubbletea Menu  │
│  TopicModelJob → CompileTurnJob ×N →    │    │  → Wizards       │
│  ReduceTurnsJob                          │    │  → Chat TUI      │
└──────────────────┬───────────────────────┘    └──────────────────┘
                   │
       ┌───────────┴───────────┐
       ▼                       ▼
┌─────────────┐         ┌─────────────┐
│  Pass 1     │         │  Pass 2     │
│  (spaCy)    │         │  (LLM)      │
│  Syntactic  │         │  Semantic   │
│  + Ideational│        │  Interpersonal│
│             │         │  + Textual   │
└──────┬──────┘         └──────┬──────┘
       │                       │
       └───────────┬───────────┘
                   ▼
┌──────────────────────────────────────────┐
│         Analysis & Aggregation           │
│  TenorTracker │ SpeakerProfiler │ Topic  │
│  Cohesion     │ Correlation     │ Graph  │
└──────────────────┬───────────────────────┘
                   │
          ┌────────┼────────┐
          ▼        ▼        ▼
     ┌────────┐┌──────┐┌────────┐
     │  JSON  ││ CSV  ││Markdown│
     └────────┘└──────┘└────────┘
```

---

## What's New (June 2026)

| Feature | What it does |
|---------|-------------|
| **CrossDocumentGraph** | Merges per-document question graphs; auto-detects cross-document findings |
| **LangfuseReachability** | Pre-flight TCP check before loading dspy; prompts continue/cancel |
| **TopicModelJob** | Topic modeling as standalone Gush job; CompileTurnJob + ReduceTurnsJob depend on it |
| **SprintWorkflow** | 4-stage pipeline: Achilles → Tortoise → Crab → Genie |

---

## Quick Start

### Install

```bash
bundle install
python -m spacy download en_core_web_sm
createdb sfl_compiler_dev && psql sfl_compiler_dev -c "CREATE EXTENSION vector;"
```

### Configure

```bash
# .env
DSPY_PROVIDER=openrouter/anthropic/claude-3-5-sonnet
OPENROUTER_API_KEY=sk-or-...
OLLAMA_BASE_URL=http://localhost:11434
EMBEDDING_MODEL=embeddinggemma:latest

# Optional: Langfuse tracing
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
```

### Run

```bash
# Analyze a conversation (parallel Gush workflow)
bundle exec sfl-analyze conversation chat.jsonl --output-dir ./output

# Analyze docs with ingestion + semantic search
bundle exec sfl-analyze documentation ./docs/ --store
bundle exec sfl-analyze context "How does error handling work?" --limit 5

# Interactive TUI
bundle exec sfl-analyze tui
```

---

## Pipeline Architecture

```
  Raw Text / JSONL
        │
        ▼
  ┌─────────────┐
  │ Bootstrap   │ ← ENV only here. Everything else gets constructor args.
  │ (LLM, DB)   │
  └──────┬──────┘
         │
    ┌────┴────┐
    ▼         ▼
  Pass 1    MarkdownLoader
  (spaCy)   (chunk+segment)
    │
    ├─ Tokenize + POS + Dependencies
    ├─ Ideational extraction (process, participants, circumstances)
    │
    ▼
  ┌──────────────┐
  │ PipelineCache │ ← SHA256(document_id + sentence_index + clause_text)
  └──────┬───────┘
         │
    ┌────┴────┐
    ▼         ▼
  Pass 2   Embedder (Ollama embeddinggemma)
  (LLM)    → pgvector
    │
    ├─ Interpersonal (mood, modality, tenor, attitude)
    ├─ Textual (theme, rheme, theme_type)
    ├─ ReasoningTrace (premises, inference_rule, derivation_hash)
    │
    ▼
  ┌──────────────────────────────────────┐
  │         Analysis Layer               │
  │  • ConversationAnalyzer (per turn)   │
  │  • TenorTracker (formality shifts)   │
  │  • SpeakerProfiler (per speaker)     │
  │  • CohesionAnalyzer (repetition, etc)│
  │  • TopicModeler (LDA/HDP)           │
  │  • CorrelationAnalyzer              │
  │  • NarrativeGenerator (LLM prose)    │
  │  • QuestionGraph (Gödel numbering)   │
  │  • CrossDocumentGraph (multi-doc)   │
  └──────────────┬───────────────────────┘
                 │
        ┌────────┼────────┐
        ▼        ▼        ▼
    ┌──────┐ ┌──────┐ ┌──────────┐
    │ JSON │ │ CSV  │ │ Markdown │
    └──────┘ └──────┘ └──────────┘
```

---

## Parallel Execution Model

```
                  ┌──────────────┐
                  │   CLI / TUI  │
                  └──────┬───────┘
                         │
              ┌──────────┴──────────┐
              │   Gush Workflow     │
              │  (Redis-backed)     │
              └──────────┬──────────┘
                         │
            ┌────────────┼────────────┐
            ▼            ▼            ▼
     ┌───────────┐ ┌───────────┐ ┌───────────┐
     │CompileTurn│ │CompileTurn│ │CompileTurn│  ← Parallel Sidekiq workers
     │  Job #1   │ │  Job #2   │ │  Job #N   │    (own Python interpreter)
     └─────┬─────┘ └─────┬─────┘ └─────┬─────┘
           │             │             │
           └─────────────┼─────────────┘
                         ▼
              ┌─────────────────────┐
              │   ReduceTurnsJob    │  ← Waits for all CompileTurnJobs
              │ (cross-turn aggreg) │
              └──────────┬──────────┘
                         ▼
                   AnalysisResult
```

---

## Data Model

```
┌─────────────────────────────────────────────────────────────┐
│                      AnnotatedClause                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐│
│  │SyntacticClause│ │Ideational    │ │InterpersonalPayload  ││
│  │  tokens[]     │ │  process_type│ │  mood, modality,     ││
│  │  groups[]     │ │  participants│ │  tenor, attitude,    ││
│  │  root_index   │ │  circumstances│ │  reasoning_trace     ││
│  └──────────────┘ └──────────────┘ └──────────────────────┘│
│  ┌──────────────────────┐                                    │
│  │TextualPayload        │  ← Optional (theme/rheme)         │
│  └──────────────────────┘                                    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    QuestionGraph (Gödel)                     │
│  Axiomatic Q → prime p          Derived Q → seed × ∏(deps) │
│  Consistent? → decode == keys   → factorize to verify       │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                   ReasoningTrace                             │
│  premises[] → inference_rule → conclusion → derivation_hash │
│  (SHA256 over premises + rule + conclusion — never trusted  │
│   from LLM output)                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Resilience Model

```
  LLM Call
     │
     ▼
  ┌──────────────────┐
  │  Circuit Breaker │  failure_threshold=5, timeout=30s
  │  (per-instance)  │  invocation_timeout=180s
  └────────┬─────────┘
           │
     ┌─────┴─────┐
     │  Retries   │  DEFAULT_BATCH_ATTEMPTS=3
     │  (3 tries) │  (absorbs ~15% provider flakiness)
     └─────┬─────┘
           │
     ┌─────┴─────┐
     │  Watchdog  │  chunk_timeout=180s
     │  (Timeout) │  (catches hung sockets)
     └─────┬─────┘
           │
     ┌─────┴──────────────┐
     │  Fallback Ladder   │
     │  → defaults (0.5)  │
     │  → annotation_source="fallback" │
     │  → data quality section in report│
     └────────────────────┘
```

---

## Observability

```
  exe/sfl-analyze
       │
       ├─ .env loaded (before require "sfl-compiler")
       │
       ▼
  ┌─────────────────────────┐
  │ LangfuseReachability    │
  │ TCP connect to host:443 │
  │ → :traced / :skip / :cancel│
  └────────┬────────────────┘
           │
     ┌─────┴─────┐
     │  Continue? │  (interactive prompt if unreachable)
     └─────┬─────┘
           │
       require "sfl-compiler"
           │
           ▼
  ┌─────────────────────────┐
  │ dspy-o11y-langfuse      │  ← one-shot decision at require-time
  │ OpenTelemetry install   │
  │ Journald logging        │
  └─────────────────────────┘
```

---

## Directory Structure

```
lib/sfl/compiler/
├── cli.rb                    # Argv parsing → dispatch
├── bootstrap.rb              # ENV → Configuration + DB + DSPy + Observability
├── pipeline.rb               # Orchestrator: Pass1 → GC → Pass2 → Store → Embed
├── types.rb                  # Dry::Struct definitions (AnnotatedClause, etc.)
├── question_graph.rb         # Gödel-encoded question-dependency DAG
├── cross_document_graph.rb   # Multi-document question merging
├── langfuse_reachability.rb  # Pre-flight TCP check (NOT autoloaded)
├── derivation_hash.rb        # SHA256 over premises + rule + conclusion
├── classification_registry.rb # Canonical enum values for mood/theme_type
├── pass_one/                 # spaCy → Ideational (flat constants)
├── pass_two/                 # LLM → Interpersonal + Textual (flat constants)
├── storage/                  # PostgreSQL + pgvector + PipelineCache
├── retrieval/                # Embedder + HybridRetriever (RRF)
├── analysis/                 # Aggregation modules (nested modules)
├── formatters/               # JSON / CSV / Markdown / Narrative
├── chat/                     # Bubbletea RAG chat + markdown export
├── tui/                      # Interactive menu + wizards + batch_app
├── jobs/                     # Gush jobs: CompileTurn, ReduceTurns, TopicModel
├── workflows/                # Gush workflows: ConversationAnalysis, Sprint
└── llm_tools/                # ThemeRhemeExtractor (experimental)
```

---

## Key Design Principles

| Principle | How it manifests |
|-----------|-----------------|
| **ENV only at entry points** | `Bootstrap.call` is the sole ENV reader; all other classes get constructor args |
| **UI-agnostic analyzers** | No `puts`, `exit`, or `ENV` in analysis code — testable without I/O |
| **Fail-closed LLM** | Circuit breaker → retry → fallback defaults (never crash the pipeline) |
| **Deterministic caching** | SHA256(document_id + sentence_index + clause_text) — identical input = identical output |
| **Type safety** | `Dry::Struct` with constrained enums; no raw Hashes in domain models |
| **Structured logging** | `Journald::Logger` with correlation_id on every operation |

---

## License

MIT
