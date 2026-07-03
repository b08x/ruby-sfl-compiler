# ROADMAP: SFL Compiler Evolution

**Status:** Operational — Multi-Mode Pipeline
**Parent:** [README — The Core Hypothesis: Stance-Filtered RAG (Safe RAG)](README.md#the-core-hypothesis-stance-filtered-rag-safe-rag)

---

## Current State: Operational Pipeline

The two-pass SFL compiler is operational with multiple execution modes. Raw text flows through Pass 1 (spaCy syntactic extraction) and Pass 2 (DSPy.rb LLM annotation), producing structured clauses with ideational, interpersonal, and textual payloads. Those clauses are stored in PostgreSQL with pgvector embeddings, retrievable via hybrid Reciprocal Rank Fusion with scalar stance filters.

### Execution Modes

| Mode | Trigger | Use Case |
|------|---------|----------|
| Conversation Analysis | `--mode conversation` | Turn-level aggregation, speaker profiling |
| Knowledge Base Analysis | `--mode documentation` | Multi-file doc analysis, migration assessment |
| Parallel Conversation | `--mode conversation --parallel` | Gush workflows, process isolation |
| Sprint Analysis | SprintWorkflow | Multi-agent reasoning sprints |

### Active Proofs

Two security hypotheses are under active investigation on local data:

1. **Safe RAG (Stance-Filtered Retrieval).** By configuring the retriever with
   `min_modality` and `min_tenor` filters, we hypothesize that the system can
   structurally exclude manipulative, emotionally charged, or low-formality
   text from the LLM's context window — populating retrieval results with
   objective, high-certainty evidence only. See
   [The Core Hypothesis](README.md#the-core-hypothesis-stance-filtered-rag-safe-rag).

2. **LLM Role Isolation.** By separating the ideational payload (what is
   happening) from the interpersonal payload (the persuasion and emotion) in
   the synthesis prompt, we hypothesize that the system can force the LLM to
   evaluate sterile facts rather than absorb persuasive stances — neutralizing
   "parahuman" manipulation that exploits the LLM's human-like language
   processing. See
   [docs/use-cases/llm-role-isolation.md](docs/use-cases/llm-role-isolation.md).

### What We Have Built

- **Two-pass pipeline**: spaCy → GC → LLM → Store → Embed
- **Multiple analyzers**: Conversation, Knowledge Base, Documentation
- **Parallel execution**: Gush workflows with Sidekiq workers
- **Hybrid retrieval**: RRF fusion (semantic + keyword + scalar filters)
- **Knowledge base analysis**: Content typing, quality scoring, migration assessment
- **QuestionGraph**: In-memory adjacency list with topological ordering
- **Observability**: Langfuse pre-flight checks, Journald logging
- **Trace paths**: `file:line` references for all analysis pipelines

### The Constraint We Are Addressing

The initial pipeline was optimized for reproducibility, traceability, and
rapid iteration. One architectural choice in particular has served its
research purpose and is now addressing scale:

**Sequential context accumulation.** The `SprintWorkflow` runs a single
Genie synthesis at the end of each sprint — one LLM call summarizing
everything produced by Achilles, Tortoise, and Crab. For small corpora this
is fine. For a 10,000-word incident report producing hundreds of annotated
clauses, the working memory passed to the Genie grows without bound. Every
clause from every section accumulates in context until synthesis fires. The
context window degrades before reasoning begins.

The `QuestionGraph` used to compound this with a Gödel-encoded dependency
DAG that overflowed PostgreSQL `BIGINT` at 6-7 deep nodes (a hard ceiling
that served as an implicit circuit breaker in early research). That encoding
has been replaced with a standard adjacency-list graph (`roots`, `leaves`,
`ancestors`, `descendants`, `reachable?`) — no integer arithmetic, no
overflow ceiling. But the underlying problem — holding all working memory
until a single terminal synthesis — remains.

To test the Safe RAG hypothesis on real-world datasets — deep security
incident reports, multi-day conversation trees, enterprise knowledge bases
spanning thousands of documents — the system needs to summarize
incrementally rather than accumulate exhaustively.

---

## Future Enhancements: Infinite Context & Sustainable Scaling

To properly test deep reasoning, we must abandon arbitrary math limits and
build semantic circuit breakers.

The following enhancements replace hardware-bound constraints with sustainable
context management — three architectural patterns that allow the system to
operate over arbitrarily large corpora without proportional hardware cost,
while preserving the SFL annotation pipeline that makes stance-filtered
retrieval possible.

The goal is not to remove the circuit breaker. It is to replace a
mathematical accident with a deliberate, semantically grounded one.

---

## 1. Rolling Synthesis (Fractal Graphs)

### The Problem

A 10,000-word security incident report produces hundreds of annotated
clauses. If each clause must be held in working memory alongside its
dependency relationships for downstream reasoning, the context window
exhausts itself on raw tokens before reasoning even begins.

### The Pattern

Rolling Synthesis replaces batch graph recomputation with incremental
context compression. The system triggers intermediate Genie syntheses at
semantic boundaries — section breaks, topic shifts, or when working memory
approaches a configured threshold.

The Genie is the synthesis stage of the existing SprintWorkflow (see
`lib/sfl/compiler/workflows/sprint_workflow.rb`: the four-stage
Achilles → Tortoise → Crab → Genie pipeline). Currently, the Genie
synthesizes once, at the end of a sprint. With Rolling Synthesis, the Genie
fires intermittently throughout processing.

Each intermediate synthesis:

1. **Compresses working memory** into a dense "Axiomatic" summary — a
   compact representation of the clauses processed so far, preserving
   their SFL metadata (process types, modality weights, tenor scores,
   mood distributions) but discarding the raw token sequences.
2. **Flushes raw tokens** from the active context window. The original
   clauses remain in PostgreSQL; they are not deleted, only released from
   working memory.
3. **Carries the summary forward** as the starting context for the next
   synthesis cycle. The summary becomes the axiomatic base — the "root
   primes" — for the next layer of derived reasoning.

This produces a fractal graph structure: each synthesis cycle compresses
a layer of detail into an axiomatic node, and the next layer builds on top.
The graph's depth is unbounded because each layer does not re-encode its
ancestors — it references their compressed summaries.

### What It Replaces

The single terminal Genie synthesis in `SprintWorkflow` (see
`lib/sfl/compiler/workflows/sprint_workflow.rb`). Currently the Genie fires
once, at the end of a sprint, summarizing everything Achilles, Tortoise, and
Crab produced in bulk. Rolling Synthesis replaces that batch accumulation
with incremental compression: intermediate syntheses fire at semantic
boundaries so working memory never grows unbounded.

### What It Preserves

The SFL annotation pipeline. Every clause — raw or summarized — still
carries its ideational and interpersonal payloads. Stance filters still
operate on the summarized metadata. The Safe RAG hypothesis is tested at
every layer of the fractal graph, not just at the leaf clauses.

---

## 2. Cognitive Gas

### The Problem

Standard context management counts tokens. When the token count
approaches the model's window limit, the system either truncates (losing
potentially critical evidence) or fails outright. There is no notion of
how *cognitively expensive* a given clause is — only how many tokens it
occupies.

In an SFL-annotated reasoning pipeline, this is a missed opportunity. The
compiler already knows the structural complexity of every clause: its
process type, its modality density, its tenor shift relative to
neighboring clauses. A clause that shifts register dramatically and
carries high modality is more cognitively demanding than a declarative
statement with neutral tenor, even if both occupy the same token count.

### The Pattern

Cognitive Gas allocates a semantic budget to reasoning loops rather than
a token count. Each clause consumed by a reasoning agent costs "gas"
proportional to its SFL-derived cognitive weight:

- **Process complexity** — material and mental processes cost more than
  relational or existential ones (they describe actions and mental states,
  which require more reasoning to evaluate than definitions).
- **Modality density** — high-modality clauses (strong certainty claims)
  cost more than low-modality ones (hedged possibilities), because
  evaluating a certainty claim requires the agent to verify or reject it.
- **Tenor shifts** — a clause whose tenor diverges significantly from the
  running average costs more, because the agent must context-switch to
  process it.

When a reasoning loop's gas budget approaches exhaustion, the system
forces a graceful summarization — triggering a Rolling Synthesis cycle
that compresses the remaining working memory into an Axiomatic summary
and continues with a fresh budget. The loop summarizes, flushes, and
continues rather than accumulating until the context window saturates.

### What It Replaces

The `CircuitBreaker::CircuitHandler` placeholder in `PassTwoEngine` (see
`lib/sfl/compiler/pass_two/pass_two_engine.rb`, line 173, and
`docs/decisions.md`, "Circuit Breaker Implementation"). The current
circuit breaker is a no-op pass-through (`lambda { |&block| block.call }`)
that never trips. Cognitive Gas replaces it with a semantically grounded budget
model that trips based on cognitive cost, not call count.

### What It Preserves

The degradation ladder. The principle that "Pass 1 data is always
preserved" extends to future enhancements: when a reasoning loop exhausts its gas
budget, the clauses it has already processed are not lost — they are
summarized and stored. The annotation pipeline's provenance tracking
(`annotation_source: "llm" | "fallback" | "stub"`) carries through to
summarized axioms, so downstream consumers can assess the reliability of
compressed evidence the same way they assess raw clauses today.

---

## 3. Semantic Convergence

### The Problem

A reasoning loop that revisits the same evidence, rephrases the same
argument, or cycles through equivalent clauses without making progress
is stuck. In a token-budgeted system, this manifests as slow waste — the
loop burns tokens without converging.

With unbounded context windows and reasoning depth limited only by semantic
relevance, the stuck-loop problem becomes critical. Without a circuit breaker,
a reasoning loop can run indefinitely — consuming LLM calls, database queries,
and compute without producing a result.

### The Pattern

Semantic Convergence uses the pgvector embedding space (already deployed
for hybrid retrieval) to detect entropy collapse in reasoning loops.

The system periodically embeds the reasoning loop's current working
state — the Axiomatic summary of clauses processed so far — and compares
it to the embedding of the previous checkpoint. If the cosine similarity
between consecutive checkpoints exceeds a configurable threshold (e.g.,
0.97), the system has detected that the loop is producing semantically
identical output: it is not converging on new information, it is
repeating itself.

This is entropy collapse: the reasoning loop's information content has
stopped growing. The embeddings, which normally power semantic retrieval,
become a diagnostic signal for reasoning health.

When entropy collapse is detected, the system forces a circuit break:

1. **Halt the reasoning loop.** No more LLM calls, no more retrieval.
2. **Emit the current Axiomatic summary as the final result.** The loop
   did not converge to a novel conclusion, but it did process evidence —
   that processing is the result.
3. **Log the convergence event** with the similarity threshold, the
   number of cycles elapsed, and the clauses consumed — providing an
   audit trail for why the loop was terminated.

### What It Replaces

The no-op circuit breaker in `PassTwoEngine` (see
`lib/sfl/compiler/pass_two/pass_two_engine.rb`, the
`default_circuit_breaker` lambda that never trips). Currently there is no runaway
loop detection — a stuck reasoning loop burns LLM calls indefinitely.
Semantic Convergence replaces this with a deliberate, semantically grounded circuit
breaker: the system halts because the reasoning has stopped producing new
information, which is the correct reason to stop.

### What It Preserves

The pgvector infrastructure. No new embedding model, no new vector
database, no new index type. The `Embedder` class (see
`lib/sfl/compiler/retrieval/embedder.rb`) and the ivfflat cosine index on
the `embeddings` table are reused for convergence detection. The same
embeddings that power `HybridRetriever`'s semantic search now also power
reasoning-loop health monitoring.

---

## Architecture: Current State vs. Future Enhancements

```
CURRENT STATE                              FUTURE ENHANCEMENTS
─────────────────────                      ──────────────────────
Raw Text → Pass 1 → Pass 2 → Store        Raw Text → Pass 1 → Pass 2 → Store
         (sequential, PyCall)                       (decoupled runtimes)

QuestionGraph (adjacency list, in-memory)  Rolling Synthesis (Fractal Graphs)
  - Sprint-scale only (no persistence)      - Intermediate Genie syntheses
  - Single terminal Genie synthesis         - Compress → flush → carry forward
  - Working memory grows unbounded          - Unbounded depth

CircuitBreaker (no-op placeholder)         Cognitive Gas (Semantic Budget)
  - Never trips                            - SFL-weighted cost per clause
  - Fail = database crash                  - Graceful summarization on exhaustion

No loop detection                          Semantic Convergence (Entropy Collapse)
  - Runaway loops undetected                - pgvector cosine similarity checkpoints
  - Wasted compute                         - Circuit break on entropy collapse
```

---

## Supporting Architecture Changes

### Runtime Decoupling

The in-process PyCall bridge will be replaced with a standalone syntactic
service (or a language-native parser) so that Pass 1 and Pass 2 can scale
independently and run distributed without the single-threaded PyCall
constraint. This is a prerequisite for Rolling Synthesis at scale:
intermediate Genie syntheses require concurrent Pass 1 and Pass 2
operations, which the current single-process PyCall architecture cannot
support.

See `docs/architecture.md` for the three candidate replacement approaches
(adjacency lists, Postgres Ltree, array tracking) — all of which eliminate
the integer overflow ceiling.

### Standard Relational Graph Storage

The `question_edges` table (adjacency list with `parent_id → child_id` and
a `depth` column) replaces the single-integer Gödel encoding. Recursive
CTEs handle reachability and topological ordering. Depth is bounded by
available storage, not by `BIGINT`'s maximum value.

---

## Validation Path

The codebase remains the active foundation for ongoing proof-of-concept work and the reference
implementation as the architecture evolves.

The validation sequence is:

1. **Implement Rolling Synthesis** on the existing SprintWorkflow, using
   intermediate Genie syntheses to compress multi-document sprints. Test
   on a single 10,000-word incident report. Confirm that the Axiomatic
   summary preserves SFL metadata and that stance filters operate on
   summarized evidence.

2. **Implement Cognitive Gas** as a replacement for the no-op circuit
   breaker in `PassTwoEngine`. Test with a configurable gas budget per
   reasoning loop. Confirm that graceful summarization triggers before
   resource exhaustion and that no data is silently lost.

3. **Implement Semantic Convergence** using the existing pgvector
   infrastructure. Test with a deliberately stuck reasoning loop (one that
   rephrases the same argument). Confirm that the cosine similarity
   threshold triggers a circuit break and that the audit log captures the
   convergence event.

4. **Validate the Safe RAG hypothesis at scale.** With all three patterns
   operational, test stance-filtered retrieval on enterprise-scale
   datasets — deep incident reports, multi-day conversation trees — to
   determine whether the Rhetorical Firewall holds when the context window
   is managed by Rolling Synthesis rather than bounded by Gödel numbering.

---

## Related

- [docs/architectural-lineage.md](docs/architectural-lineage.md) — interdisciplinary design synthesis
- [README — The Core Hypothesis: Stance-Filtered RAG (Safe RAG)](README.md#the-core-hypothesis-stance-filtered-rag-safe-rag)
- [docs/use-cases/llm-role-isolation.md](docs/use-cases/llm-role-isolation.md) — the Rhetorical Firewall hypothesis
- [docs/architecture.md](docs/architecture.md) — system overview, QuestionGraph, trace paths
- [docs/data-flow.md](docs/data-flow.md) — trace paths with file:line references
- [docs/decisions.md](docs/decisions.md) — Architecture Decision Records
- [lib/sfl/compiler/question_graph.rb](lib/sfl/compiler/question_graph.rb) — the adjacency-list graph
- [lib/sfl/compiler/workflows/sprint_workflow.rb](lib/sfl/compiler/workflows/sprint_workflow.rb) — Achilles → Tortoise → Crab → Genie
- [lib/sfl/compiler/pass_two/pass_two_engine.rb](lib/sfl/compiler/pass_two/pass_two_engine.rb) — circuit breaker placeholder (line 173)
- [lib/sfl/compiler/retrieval/embedder.rb](lib/sfl/compiler/retrieval/embedder.rb) — the Embedder reused for Semantic Convergence