# SFL-Compiler

> **Conversation and documentation text → SFL analysis** through a two-pass pipeline (spaCy + LLM) with Gödel-encoded question graphs and parallel Gush workflows.

---

## Key Documents

| Document | What it answers |
|----------|----------------|
| [README.md](../README.md) | What this is and why it exists (Safe RAG hypothesis) |
| [ROADMAP.md](../ROADMAP.md) | Phase 2: Rolling Synthesis, Cognitive Gas, Semantic Convergence |
| [docs/architectural-lineage.md](architectural-lineage.md) | Where every engineering pattern came from (6 disciplines) |
| [docs/guides/modular-integration.md](guides/modular-integration.md) | How to drop SFL into an existing RAG pipeline |
| [docs/use-cases/llm-role-isolation.md](use-cases/llm-role-isolation.md) | The Rhetorical Firewall hypothesis |
| [docs/guides/USAGE.md](guides/USAGE.md) | Operator guide: CLI, env vars, corpus management |
| [docs/architecture.md](architecture.md) | Pipeline internals, QuestionGraph, storage schema |
| [CLAUDE.md](../CLAUDE.md) | Agent/contributor codebase map |

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
  │    Analysis Layer (standard runs)    │
  │  • ConversationAnalyzer (per turn)   │
  │  • TenorTracker (formality shifts)   │
  │  • SpeakerProfiler (per speaker)     │
  │  • CohesionAnalyzer (repetition, etc)│
  │  • CorrelationAnalyzer              │
  │  • NarrativeGenerator (LLM prose)    │
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
│         QuestionGraph (Phase 1 research — sprint only)       │
│  Axiomatic Q → prime p          Derived Q → seed × ∏(deps) │
│  Consistent? → decode == keys   → factorize to verify       │
│  Never instantiated by standard sfl-analyze runs. Only      │
│  created inside SprintWorkflow and CrossDocumentGraph.      │
│  BIGINT overflows at ~6-7 nodes by design. ROADMAP.md §2.  │
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
