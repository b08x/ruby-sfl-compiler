# ruby-sfl-compiler

**Phase 1 Prototype — Active Proof of Concept**

A Ruby gem that compiles natural language into structured Systemic Functional
Linguistics (SFL) annotations for Retrieval-Augmented Generation (RAG). Where
conventional RAG retrieves by topic alone, this compiler also indexes
*rhetorical stance* — how certain the writer was (modality), how formal
(tenor), and what kind of process each clause describes — so retrieval can
filter on how something was said, not just what it said.

The compiler uses a two-pass pipeline: a **syntactic engine** (Pass 1, spaCy
via PyCall) extracts token-level structure and ideational content, then a
**semantic annotator** (Pass 2, DSPy.rb + LLM) classifies interpersonal
features like mood, modality, and tenor. Annotated clauses are stored in
PostgreSQL with pgvector for hybrid retrieval that combines semantic
similarity, keyword matching, and scalar stance filters.

It ships with `sfl-analyze`, a CLI that analyzes conversations and
documentation, ingests clauses into PostgreSQL, and answers questions over the
stored corpus with cited, stance-aware evidence.

---

## The Core Hypothesis: Stance-Filtered RAG (Safe RAG)

This project exists to test a single, high-stakes hypothesis:

**Can Systemic Functional Linguistics (SFL) be used to secure LLMs against
context poisoning and role confusion?**

When an LLM retrieves documents to answer a question, it can easily absorb the
emotional or manipulative stance of poisoned or highly biased documents. The
ruby-sfl-compiler is built to test a structural defense against this.

**Mechanism:** During ingestion, it stores SFL metadata alongside vector
embeddings.

**Action:** During retrieval, it uses hybrid Reciprocal Rank Fusion (RRF)
combined with scalar stance filters. By configuring the retriever to only pull
evidence where `min_modality` is high (factually confident) and `min_tenor` is
high (formal/objective register), the goal is to strictly populate the LLM's
context window with objective facts, isolating it from adopting an
inappropriate persona.

If the hypothesis holds, stance-filtered retrieval becomes a structural
defense layer — not a prompt-level guardrail, but a deterministic filter that
governs what evidence reaches the model's context window in the first place.

---

## Project Status: Phase 1 Prototype

This is an **active proof of concept**, not a production system. The current
implementation was built to establish the two-pass SFL annotation pipeline and
begin testing the Safe RAG hypothesis on real data.

### What Phase 1 Established

The Ruby/PyCall architecture and the math-based DAG (Directed Acyclic Graph)
tracking — inspired by Gödel numbering — have successfully established the
full pipeline:

- **Two-pass annotation** from raw text through SFL-tagged, embedding-ready
  clauses stored in PostgreSQL.
- **Hybrid retrieval** combining semantic vector search, keyword matching, and
  scalar stance filters via Reciprocal Rank Fusion.
- **Provenance tracking** — every clause carries an `annotation_source` marker
  so fallback or placeholder data is never silently presented as measurement.

We are currently working out the practical proofs and use cases on local data
— validating which SFL filter combinations produce materially different
retrieval outcomes and whether stance filtering demonstrably changes the
quality and objectivity of LLM-generated answers.

### Architectural Decisions Suited to Research, Not Production

The Phase 1 architecture was deliberately optimized for reproducibility,
traceability, and rapid iteration — not for throughput, horizontal
scalability, or production deployment:

- **Ruby + Python via PyCall.** Pass 1 delegates to spaCy through PyCall,
  which bridges Ruby and an embedded Python interpreter in a single process.
  This eliminated serialization overhead during research but introduces a
  single-threaded constraint (PyCall does not support multi-threaded use) and
  couples two language runtimes tightly.

- **Gödel-numbered DAG tracking.** Clause relationships and analysis
  dependencies are tracked through mathematical encodings rather than
  conventional graph data structures. This approach was valuable for academic
  validation — every transformation is provably traceable — but it is
  hardware-bound and not suited to distributed or high-volume processing.

- **Low-volume by design.** The pipeline processes clauses sequentially (or
  across Sidekiq worker processes for parallelism), stores results in a local
  PostgreSQL instance, and targets corpus sizes typical of academic
  experiments and single-document analysis.

---

## Architectural Lineage: A Composite Design

This project is a composite architecture — a system built by
reverse-engineering and synthesizing design patterns from a radically diverse
array of research domains that usually do not interact: Systemic Functional
Linguistics, Cognitive Behavioral Therapy, cognitive neuroscience,
existential philosophy, the Unix philosophy, and cybersecurity practice.

For the full intellectual lineage of every engineering pattern in the
compiler, see [docs/architectural-lineage.md](docs/architectural-lineage.md).

---

## Architecture

```shell
Raw Text
   │
   ▼
┌─────────────────────────────┐
│  PASS 1: Syntactic Engine   │
│  (ruby-spacy via PyCall)    │
│                             │
│  - Tokenization             │
│  - POS tagging              │
│  - Dependency parsing       │
│  - Sentence segmentation    │
│         │                   │
│         ▼                   │
│  Ideational Extractor       │
│  (rule-based, no LLM)       │
│  - Process type             │
│  - Participants (roles)     │
│  - Circumstances            │
└──────────┬──────────────────┘
           │ SyntacticClause + IdeationalPayload
           ▼
┌─────────────────────────────┐
│  PASS 2: PassTwoEngine      │
│  (DSPy.rb + LLM, batched)   │
│                             │
│  - Mood classification      │
│  - Modality weight (0-1)    │
│  - Tenor / formality (0-1)  │
│  - Speaker attitude         │
│                             │
│  ~12 clauses per LLM call,  │
│  4 concurrent calls, retry  │
│  on transient errors.       │
│  Failed clauses fall back   │
│  to defaults marked         │
│  annotation_source:         │
│  "fallback" — never silent  │
└──────────┬──────────────────┘
           │ AnnotatedClause
           ▼
┌─────────────────────────────┐
│  Storage (PostgreSQL)       │
│                             │
│  clauses              (base)│
│  ideational_payloads  (P1)  │
│  interpersonal_payloads(P2) │
│  embeddings           (vec) │
│                             │
│  Scalar indices: mood,      │
│  modality_weight, tenor,    │
│  process_type               │
│  Vector index: ivfflat      │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Hybrid Retriever (RRF)     │
│  semantic + keyword search, │
│  scalar stance filters      │
│         │                   │
│         ▼                   │
│  ContextSynthesizer         │
│  LLM answer grounded in     │
│  numbered, cited evidence   │
└─────────────────────────────┘

Analysis layer (UI-agnostic, used by the CLI):
  Bootstrap → Pipeline → ConversationAnalyzer / DocumentationAnalyzer
            → AnalysisResult → ReportWriter (CSV + JSON + Markdown)
            → NarrativeGenerator (LLM-written interpretive narrative, optional)
```

## Prerequisites

- **Ruby** >= 3.3.0
- **PostgreSQL** with the `vector` (pgvector) and `pg_trgm` extensions
- **Python spaCy** with the `en_core_web_sm` model
- An **LLM API key** for Pass 2 (OpenRouter, Google, OpenAI, or Anthropic)
- **Redis** — only if running conversation analysis in parallel via the Gush
  workflow (see [Parallel Conversation Analysis](#parallel-conversation-analysis-gush--sidekiq)); not needed for the default `sfl-analyze conversation` command

## Installation

Add to your Gemfile:

```ruby
gem "sfl-compiler"
```

Install the Python side:

```bash
pip install spacy
python -m spacy download en_core_web_sm
```

## Environment Configuration

Create a `.env` file in the project root (copy from `.env.example`):

```bash
# Database
DATABASE_URL=postgresql:///sfl_compiler_dev

# LLM provider for Pass 2 (interpersonal annotation)
DSPY_PROVIDER=openrouter/mistralai/mistral-7b-instruct

# API key matching the provider prefix (set exactly one)
OPENROUTER_API_KEY=sk-or-...here   # openrouter/...
# GOOGLE_API_KEY=your-key-here           # google/...
# OPENAI_API_KEY=***        # openai/...
# ANTHROPIC_API_KEY=your-key-here        # anthropic/...

# spaCy model
SPACY_MODEL=en_core_web_sm

# Optional Pass 2 tuning
# SFL_BATCH_SIZE=12      # clauses per LLM call
# SFL_CONCURRENCY=4      # concurrent LLM calls

# Optional — only needed for the parallel Gush workflow (see below)
# REDIS_URL=redis://localhost:6379
```

The CLI resolves the API key from the provider prefix and fails fast with a
clear error for unsupported prefixes or missing keys. Embeddings (used by
semantic search and `context` queries) use Ollama `embeddinggemma:latest`
(requires `OLLAMA_BASE_URL` and `EMBEDDING_MODEL` in `.env`). Without them,
ingestion degrades gracefully to clause-only storage and retrieval falls back
to keyword search.

## The sfl-analyze CLI

Four subcommands cover the analyze → ingest → query → narrate workflow.

### Analyze a conversation

```bash
bundle exec sfl-analyze conversation chat.jsonl --output-dir ./output
```

Input is JSONL, one turn per line:

```jsonl
{"name":"Alice","send_date":"June 10, 2026 2:30pm","mes":"Message text..."}
{"name":"Bob","send_date":"June 10, 2026 2:31pm","mes":"Response text..."}
```

Each turn compiles through both passes; the analysis tracks tenor evolution,
builds per-speaker profiles (average tenor/modality, mood distribution,
dominant process types), correlates process types with stance, and generates
insights such as tenor trend across the conversation, the dominant speaker's
share of turns, and modality↔tenor correlation strength.

### Analyze (and optionally ingest) documentation

```bash
bundle exec sfl-analyze documentation docs/ --store --output-dir ./output
```

Accepts a markdown file or a directory (recursive). Sections are chunked by
heading and profiled the way conversation turns are — the report shows
per-section stance profiles and formality flow through the document. With
`--store`, every clause and its embedding is persisted for later `context`
queries; re-running on the same document replaces its previous clauses rather
than duplicating them.

### Query the stored corpus

```bash
bundle exec sfl-analyze context "what is scalar filtering used for?" \
  --min-modality 0.7 --limit 5
```

Runs hybrid retrieval (semantic + keyword, merged with Reciprocal Rank
Fusion), applies any stance filters (`--mood`, `--min/max-tenor`,
`--min/max-modality`), and synthesizes an answer grounded in the retrieved
clauses — printed with a confidence score and the evidence list, cited
clauses marked with `*`. Add `--output-dir` to also write
`context_synthesis.json`.

### Report output

`conversation` and `documentation` write three files to `--output-dir`
(default `./sfl_output`):

| File | Purpose |
|------|---------|
| `conversation_analysis.csv` | Turn-by-turn data for spreadsheets |
| `conversation_analysis.json` | Structured data, including `annotation_coverage` metadata |
| `conversation_analysis.md` | Human-readable report with profiles, correlations, insights |

When any clauses carry fallback or placeholder interpersonal values (LLM
failures, or `--pass1-only` runs), the markdown report opens with a
**Data Quality** section stating exactly how many — averages biased toward
0.5 are never presented silently as findings.

Use `--pass1-only` on either analysis subcommand to skip the LLM entirely:
process types and participants are still extracted, and all interpersonal
values are explicitly marked as placeholders.

### Narrative reports

```bash
bundle exec sfl-analyze narrate ./output/conversation_analysis.json --output-dir ./output
```

Reads a previously written report JSON (it must contain the `turns` array —
re-run `conversation`/`documentation` if it predates this feature) and makes
one LLM call to write `narrative_report.md`: an interpretive overview, cast &
roles, interpersonal dynamics, conversational arc, data quality, and
takeaways, grounded in the report's statistics and message previews. Add
`--narrative` to `conversation`/`documentation` to generate it inline right
after the CSV/JSON/MD trio — that path is best-effort and only warns on
failure, while `narrate` itself exits 1 on error.

## Parallel Conversation Analysis (Gush / Sidekiq)

`sfl-analyze conversation` compiles turns one at a time on the main thread.
For long conversations, a [Gush](https://github.com/chaps-io/gush) workflow
compiles every turn in parallel instead — one `CompileTurnJob` per turn, run
by Sidekiq worker processes, fanning into one `ReduceTurnsJob` that runs the
same cross-turn aggregation (tenor tracking, speaker profiles, correlations).

This is a library-level capability today, not yet a `sfl-analyze` flag.
Requires Redis (`REDIS_URL` in `.env`, defaults to `redis://localhost:6379`)
and a running worker:

```bash
bundle exec sidekiq -q gush -r ./lib/sfl/compiler/sidekiq_boot.rb
```

Then, from another process:

```ruby
require "sfl-compiler"

flow = SFL::Compiler::ConversationAnalysisWorkflow.create("chat.jsonl")
flow.start!

flow.reload
flow.status   #=> :pending | :running | :finished | :failed
```

Each turn's Pass 1 (spaCy) runs in its own Sidekiq **process** rather than a
Ruby thread — deliberately, since
[PyCall does not support multi-threaded use](https://github.com/red-data-tools/pycall.rb)
and calling it from a thread inside one process can segfault. Process-level
parallelism sidesteps that restriction entirely.

Not yet supported by this workflow: the optional topic-modeling pre-pass, and
an equivalent for `documentation`. `ReduceTurnsJob`'s output currently
forwards only `metadata`/`insights`, not the full per-speaker profiles or
correlations — fine for confirming the workflow ran, not yet a drop-in
replacement for `ConversationAnalyzer#analyze`'s return value.

## Library Usage

The CLI is a thin layer; everything is available programmatically.

### Full pipeline

```ruby
require "sfl-compiler"

ctx = SFL::Compiler::Bootstrap.call   # .env → config, DSPy, database
pipeline = SFL::Compiler::Pipeline.new(db: ctx.db)

annotated = pipeline.compile(
  "The system processes user input and validates it against known patterns.",
  document_id: "doc-1"
)

annotated.each do |ac|
  puts "#{ac.text} → #{ac.ideational.process_type}, " \
       "mood=#{ac.interpersonal.mood}, tenor=#{ac.interpersonal.tenor} " \
       "(#{ac.interpersonal.annotation_source})"
end
```

`annotation_source` is `"llm"` for real annotations, `"fallback"` when Pass 2
failed for that clause, `"stub"` when Pass 2 was skipped.

### Pass 1 only (no LLM)

```ruby
pairs = pipeline.compile_pass_one("Your text here")
pairs.each do |clause, ideational|
  puts "#{ideational.process_type}: #{clause.text}"
end
```

### Retrieval with stance filters

```ruby
retriever = SFL::Compiler::HybridRetriever.new(db: ctx.db)

results = retriever.retrieve(
  "input validation",
  filters: { min_modality: 0.7, min_tenor: 0.5, process_type: "material" }
)
```

### Analyzers and synthesis

The CLI's building blocks are plain objects with injected dependencies and an
optional progress callback — designed to back other front ends (a TUI, a web
UI) without modification:

```ruby
analyzer = SFL::Compiler::Analysis::ConversationAnalyzer.new(
  pipeline: pipeline,
  on_progress: ->(e) { puts "turn #{e[:turn_id]}/#{e[:total]}" }
)
result = analyzer.analyze("chat.jsonl")   # → Types::AnalysisResult

SFL::Compiler::Formatters::ReportWriter.write(result, "./output")

synthesizer = SFL::Compiler::ContextSynthesizer.new(
  retriever: retriever,
  clause_repo: SFL::Compiler::ClauseRepository.new(ctx.db)
)
answer = synthesizer.synthesize("what does the corpus say about X?")
```

## Payload Separation

SFL metafunctions live in separate tables so they can be indexed and filtered
independently:

| Table | Source | Content |
|-------|--------|---------|
| `clauses` | Pass 1 | Raw text, tokens, dependency tree |
| `ideational_payloads` | Pass 1 | Process type, participants, circumstances |
| `interpersonal_payloads` | Pass 2 | Mood, modality_weight, tenor, attitude |
| `embeddings` | Embedder | Vector embeddings for semantic search |

## Scalar Filtering

The interpersonal payload supports scalar metadata filtering:

- **Modality weight** (0.0–1.0): strength of certainty —
  "must" ≈ 0.9, "should" ≈ 0.7, "might" ≈ 0.3
- **Tenor** (0.0–1.0): formality of register —
  technical documentation ≈ 0.8, casual chat ≈ 0.2
- **Mood**: declarative, interrogative, imperative, exclamative

## Development

```bash
bundle install
bundle exec rspec spec/        # unit suite
```

See `docs/guides/USAGE.md` for the operator-focused guide,
`docs/guides/modular-integration.md` for the RAG middleware integration guide,
and `CLAUDE.md` for the agent/contributor codebase map.

---

## Roadmap to Phase 2

Phase 1 established the pipeline. Phase 2 tests the Safe RAG hypothesis at
scale.

To test these proofs on massive enterprise datasets, the next iteration
focuses on replacing the hardware-bound limits of Phase 1 with sustainable
context management.

### Rolling Synthesis

An incremental context window that maintains SFL annotations as living state
rather than recomputing clause graphs from scratch. As new clauses arrive, the
synthesis rolls forward, preserving rhetorical continuity without replaying
the full analysis history.

Rolling Synthesis replaces the Gödel-numbered DAG tracking — which requires
re-evaluating the full clause graph and is constrained by the mathematical
encoding's memory footprint — with a streaming, semantically grounded model
that can operate over arbitrarily large corpora without proportional hardware
cost.

### Supporting Architecture Changes

- **Runtime decoupling.** The in-process PyCall bridge will be replaced with a
  standalone syntactic service (or a language-native parser) so that Pass 1
  and Pass 2 can scale independently and run distributed without the
  single-threaded PyCall constraint.

- **Cognitive Gas.** A semantic budget model for LLM context. Rather than
  tracking token counts or fixed window sizes, the system measures the
  "cognitive cost" of each clause in SFL terms (process complexity, modality
  density, tenor shifts) and allocates retrieval and generation budget
  accordingly. This replaces the math-based DAG with a dynamic, semantically
  grounded approach to context management.

Phase 2 is in the design stage. The Phase 1 codebase remains the active
foundation for ongoing proof-of-concept work and the reference implementation
as the architecture evolves.

For the full engineering roadmap — including Rolling Synthesis (Fractal
Graphs), Cognitive Gas, and Semantic Convergence — see
[ROADMAP.md](ROADMAP.md).

---

## License

MIT