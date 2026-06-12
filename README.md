# Two-Pass SFL Compiler

A Ruby gem that compiles natural language into structured Systemic Functional
Linguistics (SFL) annotations for high-fidelity Retrieval-Augmented Generation
(RAG). Where conventional RAG retrieves by topic alone, this compiler also
indexes *rhetorical stance* — how certain the writer was (modality), how formal
(tenor), and what kind of process each clause describes — so retrieval can
filter on how something was said, not just what it said.

It ships with `sfl-analyze`, a CLI that analyzes conversations and
documentation, ingests clauses into PostgreSQL, and answers questions over the
stored corpus with cited, stance-aware evidence.

## Architecture

```
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
```

## Prerequisites

- **Ruby** >= 3.3.0
- **PostgreSQL** with the `vector` (pgvector) and `pg_trgm` extensions
- **Python spaCy** with the `en_core_web_sm` model
- An **LLM API key** for Pass 2 (OpenRouter, Google, OpenAI, or Anthropic)

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
OPENROUTER_API_KEY=sk-or-your-key-here   # openrouter/...
# GOOGLE_API_KEY=your-key-here           # google/...
# OPENAI_API_KEY=sk-your-key-here        # openai/...
# ANTHROPIC_API_KEY=your-key-here        # anthropic/...

# spaCy model
SPACY_MODEL=en_core_web_sm

# Optional Pass 2 tuning
# SFL_BATCH_SIZE=12      # clauses per LLM call
# SFL_CONCURRENCY=4      # concurrent LLM calls
```

The CLI resolves the API key from the provider prefix and fails fast with a
clear error for unsupported prefixes or missing keys. Embeddings (used by
semantic search and `context` queries) additionally require `OPENAI_API_KEY` —
the embedder calls `text-embedding-ada-002`. Without it, ingestion degrades
gracefully to clause-only storage and retrieval falls back to keyword search.

## The sfl-analyze CLI

Three subcommands cover the analyze → ingest → query workflow.

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

See `USAGE.md` for the operator-focused guide and `CLAUDE.md` for the
agent/contributor codebase map.

## License

MIT
