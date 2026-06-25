# Data Flow

How text flows through the system, from CLI invocation to formatted output.

---

## Quick Reference

```
CLI ──► Bootstrap ──► Workflow ──► Pipeline (per turn) ──► Analysis ──► Formatter
                          │
                          ├── TopicModelJob (optional)
                          ├── CompileTurnJob ×N (parallel)
                          └── ReduceTurnsJob (fan-in)
```

---

## Primary Path: Conversation Analysis

```
     ┌──────────────────────────────────────────────────────────────────────┐
     │                     ConversationAnalysisWorkflow                       │
     │                                                                      │
     │  JSONL ──► load_jsonl ──► [turn, turn, turn, ...]                   │
     │                              │                                       │
     │                    ┌─────────┴─────────┐                             │
     │                    ▼                   ▼                             │
     │            topics ≥ 3?            topics < 3?                         │
     │                    │                   │                             │
     │            TopicModelJob        (skip topic job)                     │
     │            (fit LDA/HDP)                                            │
     │                    │                                                 │
     │         ┌──────────┴──────────┐                                      │
     │         ▼                     ▼                                      │
     │   CompileTurnJob #1     CompileTurnJob #2 ... #N                     │
     │   (own Sidekiq worker, own Python interpreter)                      │
     │         │                     │                                      │
     │         └──────────┬──────────┘                                      │
     │                    ▼                                                 │
     │            ReduceTurnsJob                                            │
     │            (TenorTracker, Cohesion, SpeakerProfile,                  │
     │             Correlation, KeyMoments, ExamplePassages)                │
     │                    │                                                 │
     │                    ▼                                                 │
     │             AnalysisResult                                           │
     └──────────────────────────────────────────────────────────────────────┘
```

---

## Per-Turn Compilation (Inside CompileTurnJob)

```
  turn_data {name, send_date, mes}
       │
       ▼
  ┌────────────────────┐
  │ Pipeline#compile   │
  │                    │
  │  Pass 1:           │
  │    spaCy tokenize  │
  │    POS + deps      │
  │    Ideational      │ ──► process_type, participants, circumstances
  │                    │
  │  GC.start          │  ◄── CRITICAL: sweep PyCall wrappers before Pass 2
  │                    │      (prevents PyGILState_Ensure deadlock)
  │  Pass 2:           │
  │    Build context    │
  │    ┌──────────────┐ │
  │    │CircuitBreaker│ │
  │    │  → 3 retries  │ │
  │    │  → 180s watch │ │
  │    │  → fallback   │ │
  │    └──────┬───────┘ │
  │           │         │
  │    DSPy::ChainOfThought(SFLBatchSignature)                             │
  │                    │
  │  Store:            │
  │    ClauseRepository│
  │    EmbeddingRepo   │
  │    PipelineCache   │
  └────────────────────┘
       │
       ▼
  Types::ConversationTurn (output via Types.dump → JSON-safe)
```

---

## Annotation Flow Detail

```
  SyntacticClause + IdeationalPayload
              │
              ▼
  ┌──────────────────────┐
  │ format_syntactic_    │
  │ context()            │
  │                      │
  │ "Text: ...           │
  │  Root verb: ...      │
  │  Process type: ...   │
  │  Participants: ...   │
  │  POS tags: ...       │
  │  Dependencies: ...   │
  │  Semantic coherence: │
  │   0.87"              │
  └──────────┬───────────┘
             │
             ▼
  ┌───────────────────────────┐
  │ SFLBatchAnnotator.call   │
  │                           │
  │ "Clause 0\n<context>\n   │
  │  Clause 1\n<context>\n   │
  │  ..."                     │
  └──────────┬────────────────┘
             │
             ▼
  ┌───────────────────────────┐
  │ DSPy::ChainOfThought      │
  │ (SFLBatchSignature)       │
  │                           │
  │   Input:  clauses string  │
  │   Output: annotations[]   │
  │     • mood                │
  │     • modality_weight     │
  │     • tenor               │
  │     • premises[]         │
  │     • inference_rule      │
  │     • conclusion          │
  └──────────┬────────────────┘
             │
             ▼
  ┌───────────────────────────────────────┐
  │ PassTwoEngine#interpersonal_from      │
  │                                       │
  │  ClassificationRegistry.normalize    │
  │    → mood validated against enum      │
  │    → theme_type validated            │
  │    → clamp01 on modality/tenor       │
  │    → derivation_hash computed from   │
  │      actual values (never trusted     │
  │      from LLM output)                │
  │                                       │
  │  Types::InterpersonalPayload.new     │
  │    annotation_source: "llm"          │
  │    reasoning_trace: {                │
  │      premises, inference_rule,       │
  │      conclusion, derivation_hash     │
  │    }                                 │
  └───────────────────────────────────────┘
```

---

## Documentation Analysis Path

```
  ./docs/**/*.md
       │
       ▼
  ┌────────────────┐
  │ MarkdownLoader │
  │                │
  │ • Parse headings│
  │ • Chunk sections│
  │ • PDF support  │
  └───────┬────────┘
          │
          ▼
  ┌────────────────────────┐
  │ DocumentationAnalyzer  │
  │                        │
  │  For each section:     │
  │    Pipeline#compile    │
  │    (synchronous)       │
  │                        │
  │  Then:                 │
  │    TenorTracker        │
  │    NarrativeGenerator  │
  └───────────┬────────────┘
              │
              ▼
       AnalysisResult
```

---

## Context Synthesis (Retrieval)

```
  "How does error handling work?"
       │
       ▼
  ┌────────────────────────────────┐
  │ HybridRetriever#retrieve       │
  │                                │
  │  ┌────────────┐                │
  │  │ Embedder   │ text → vector  │
  │  └─────┬──────┘                │
  │        │                       │
  │  ┌─────┴─────┐                 │
  │  ▼           ▼                 │
  │  Semantic   Keyword            │
  │  (vector)   (fulltext)         │
  │  │           │                 │
  │  └─────┬─────┘                 │
  │        ▼                       │
  │  RRF Fusion (k=60)             │
  │        │                       │
  │  ┌─────┴─────┐                 │
  │  ▼           ▼                 │
  │  Scalar     Limit              │
  │  filters    (default 10)       │
  └──────────┬─────────────────────┘
             │
             ▼
       [Clause matches with scores]
```

---

## Resume and Caching

```
  --resume flag
       │
       ▼
  ┌──────────────────────────────────────────┐
  │ PipelineCache                            │
  │                                          │
  │  Cache Key: SHA256(                      │
  │    document_id +                         │
  │    sentence_index +                      │
  │    clause_text                           │
  │  )                                       │
  │                                          │
  │  .sfl-cache/                             │
  │  ├── doc001-0-<hash>.json                │
  │  ├── doc001-1-<hash>.json                │
  │  └── doc001-2-<hash>.json                │
  │                                          │
  │  Compile flow:                           │
  │    partition() → cached | uncached       │
  │    Pass 2 only on uncached               │
  │    merge back in original order          │
  └──────────────────────────────────────────┘
```

---

## Reasoning Trace Flow

```
  LLM returns premises + inference_rule
              │
              ▼
  ┌──────────────────────────────────────┐
  │ Types::ReasoningTrace.new            │
  │                                      │
  │  premises: [                         │
  │    {type: "modal_adjunct",           │
  │     source: "certainly",             │
  │     value: "high_modality",          │
  │     weight: 0.9},                    │
  │    ...                               │
  │  ],                                  │
  │  inference_rule:                     │
  │    "tenor_high_formal_register",      │
  │  conclusion: {mood: "declarative",   │
  │              modality_weight: 0.92},  │
  │  confidence: 0.87,                   │
  │  derivation_hash: SHA256(            │
  │    premises + rule + conclusion      │
  │  ),                                  │
  │                                      │
  │  ⚠  hash is COMPUTED here,          │
  │    never read from LLM output        │
  │  ⚠  bad premises don't default the   │
  │    clause's mood/tenor — only the    │
  │    reasoning_trace is left nil       │
  └──────────────────────────────────────┘
              │
              ▼
       Stored in JSON formatter
       (visible to consumers)
       + CrabConstraintJob verifies reproducibility
```

---

## Sprint Workflow Data Flow

```
  domain_payload { input, propose_signature, ... }
       │
       ▼
  ┌──────────────────────────────────────────────┐
  │ SprintWorkflow                               │
  │                                              │
  │  SprintRoleJob(:achilles)                    │
  │    → proposes claims                         │
  │         │                                    │
  │         ▼                                    │
  │  SprintRoleJob(:tortoise)                   │
  │    → challenges claims (reads prior_output)  │
  │         │                                    │
  │         ▼                                    │
  │  CrabConstraintJob                           │
  │    → pins invariants (field op value rules)  │
  │    → derivation_hash_reproducible check      │
  │         │                                    │
  │         ▼                                    │
  │  SprintRoleJob(:genie)                       │
  │    → synthesizes final output                │
  └──────────────────────────────────────────────┘
```

---

## Cross-Document Graph Flow

```
  Sprint A → QuestionGraph ──┐
  Sprint B → QuestionGraph ──┤
  Sprint C → QuestionGraph ──┘
              │
              ▼
  ┌──────────────────────────────────────────┐
  │ CrossDocumentGraph.aggregate             │
  │                                          │
  │  1. Namespace question ids per document  │
  │     doc0.modality, doc1.modality, ...    │
  │  2. Topological sort each graph          │
  │  3. Detect new derived questions that     │
  │     only emerge cross-document            │
  │  4. If findings provided: reconcile       │
  │     numeric divergence > 0.3 threshold    │
  │  5. Return merged QuestionGraph           │
  └──────────────────────────────────────────┘
              │
              ▼
  Cross-document findings + deferred_questions
  (for downstream card creation by caller)
```

---

## Observability Data Flow

```
  exe/sfl-analyze
       │
       ├─── no LANGFUSE keys ──► tracing disabled
       │
       ├─── keys present ──► LangfuseReachability.reachable?
       │         │                    │
       │         │◄── TCP connect ────┘
       │         │    to host:443
       │         │
       │      reachable ──► tracing enabled
       │
       │      unreachable + interactive ──► prompt
       │              │                      │
       │              ├── "yes" ──► skip tracing, continue
       │              └── "no"  ──► exit
       │
       └─── --disable-tracing ──► skip all of above
```
