# SFL Compiler Usage Guide

The `sfl-analyze` CLI has three subcommands forming one workflow: analyze
conversations or documentation, optionally **ingest** documentation into
PostgreSQL, then **query** the stored corpus with stance filters.

## Quick Start

### 1. Configure Environment

Edit `.env` and set a provider plus its matching key. The CLI supports four
provider prefixes and resolves the key automatically:

```bash
# OpenRouter (one key, many models)
DSPY_PROVIDER=openrouter/mistralai/mistral-7b-instruct
OPENROUTER_API_KEY=sk-or-your-key-here

# OR Google Gemini
DSPY_PROVIDER=google/gemini-2.0-flash-exp
GOOGLE_API_KEY=your-key-here

# OR OpenAI
DSPY_PROVIDER=openai/gpt-4o-mini
OPENAI_API_KEY=sk-your-key-here

# OR Anthropic
DSPY_PROVIDER=anthropic/claude-3-5-sonnet-20241022
ANTHROPIC_API_KEY=your-key-here
```

Any other prefix makes the CLI exit with
`Unsupported DSPY_PROVIDER: ...`. (The library itself accepts anything
DSPy.rb supports — configure `DSPy.configure { |c| c.lm = ... }` yourself and
skip `Bootstrap` — but the CLI's provider map is those four.)

For semantic search and `context` queries you also need Ollama running with
`embeddinggemma:latest` model (configure `OLLAMA_BASE_URL` and `EMBEDDING_MODEL`
in `.env`). Without it, `--store` still persists clauses (no embeddings) and
retrieval works keyword-only.

### 2. Run an Analysis

```bash
# Conversation
bundle exec sfl-analyze conversation /path/to/conversation.jsonl --output-dir ./output

# Documentation (file or directory), ingesting for later queries
bundle exec sfl-analyze documentation docs/ --store --output-dir ./output

# Or via the Claude Code skill
/sfl-analyze conversation /path/to/conversation.jsonl
```

The console shows per-turn (or per-section) progress with timing and a
`DEFAULTED` count whenever clauses fell back to placeholder values:

```
  1/5 (Alice) 7.82s [OK]
  2/5 (Bob) 27.52s [2/2 DEFAULTED]
```

### 3. Check Results

Three files land in the output directory:

- `conversation_analysis.csv` — turn-by-turn data for spreadsheet analysis
- `conversation_analysis.json` — structured data; `metadata.annotation_coverage`
  reports how many clauses are LLM-annotated vs fallback/stub
- `conversation_analysis.md` — human-readable report; opens with a
  **⚠️ Data Quality** section if any clauses carry placeholder values

### 4. Query the Stored Corpus

After at least one `documentation --store` run:

```bash
bundle exec sfl-analyze context "what is scalar filtering used for?" --limit 5

# With stance filters
bundle exec sfl-analyze context "deployment steps" \
  --mood declarative --min-modality 0.7 --min-tenor 0.5
```

Output is a synthesized answer with a confidence score, followed by the
retrieved evidence; clauses the model actually cited are marked `*`. Notes:

- Keyword search requires **all** query terms to appear in a clause — short,
  content-bearing queries ("scalar filtering") beat full questions when no
  embeddings are stored.
- `--output-dir` additionally writes `context_synthesis.json`.
- Re-ingesting a document with `--store` replaces its previous clauses
  (idempotent per document) — counts don't grow on re-runs.

### 5. Narrative reports

Generate an LLM-written interpretive narrative — overview, cast & roles,
interpersonal dynamics, conversational arc, data quality, and takeaways —
from an analysis. Two ways to get one:

```bash
# From an existing report JSON (the turns array is required)
bundle exec sfl-analyze narrate ./output/conversation_analysis.json \
  --output-dir ./output

# Or generate it inline, right after the CSV/JSON/MD trio
bundle exec sfl-analyze conversation chat.jsonl --output-dir ./output --narrative
bundle exec sfl-analyze documentation docs/ --output-dir ./output --narrative
```

Either form writes `narrative_report.md` to the output directory. The
narrative always includes a **Data Quality** section summarizing annotation
coverage, and it never interprets tenor/modality for turns where most clauses
are fallback/stub — those turns are described as unmeasured rather than
analyzed.

Failure semantics differ by form:

- `narrate` is **fatal** — a missing file, invalid JSON, or LLM failure
  prints `[ERROR] ...` and exits 1.
- `--narrative` is **best-effort** — a failure prints
  `[WARN] narrative generation failed: ...` to stderr but the CSV/JSON/MD
  trio (already written) is unaffected and the command still exits 0.

Report JSONs written before this feature don't have a `turns` array.
`narrate`ing one of those fails fast with `[ERROR] Report JSON has no
`turns` array — it predates narrative support. Re-run the analysis to
regenerate it.` — re-run `conversation`/`documentation` to produce a JSON
with `turns`, then `narrate` that.

## Input Format (conversation)

JSONL, one turn per line:

```json
{"name":"Alice","is_user":true,"send_date":"June 10, 2026 2:30pm","mes":"Hello, how are you?","extra":{}}
{"name":"Bob","is_user":false,"send_date":"June 10, 2026 2:31pm","mes":"I'm doing great, thanks!","extra":{}}
```

**Required fields**: `name` (speaker), `send_date` (flexible format), `mes`
(message text). Other fields are ignored. Unparseable lines are skipped.

## Understanding the Output

### Tenor (Formality)

- **0.0–0.3**: casual/informal (chat, DMs)
- **0.3–0.6**: mixed (email, Slack)
- **0.6–1.0**: formal/technical (docs, papers)

### Modality (Certainty)

- **0.0–0.3**: hedged/uncertain ("might", "could", "perhaps")
- **0.3–0.6**: moderate ("should", "would", "likely")
- **0.6–1.0**: certain/assertive ("will", "must", "definitely")

### Process Types

- **Material**: actions ("run", "build", "deploy")
- **Mental**: thoughts/feelings ("think", "want", "know")
- **Verbal**: communication ("say", "tell", "ask")
- **Relational**: states/attributes ("is", "has", "becomes")
- **Behavioral**: physiological ("laugh", "sigh", "breathe")
- **Existential**: existence ("there is", "exists")

### Annotation provenance

Every clause records where its interpersonal values came from:

- `llm` — real Pass 2 annotation
- `fallback` — the LLM call failed for this clause; defaults substituted
  (tenor 0.5, modality 0.5, declarative)
- `stub` — Pass 2 was skipped (`--pass1-only`)

Reports aggregate this into the Data Quality section so placeholder-heavy
results are never mistaken for findings.

## Pass 2 Performance Tuning

Pass 2 batches clauses into LLM calls and runs calls concurrently. Defaults
work for most cases; override via environment:

```bash
SFL_BATCH_SIZE=12      # clauses per LLM call
SFL_CONCURRENCY=4      # concurrent in-flight calls
```

A chunk that fails transiently is retried once before its clauses fall back
to defaults.

## Troubleshooting

### "Unsupported DSPY_PROVIDER"

The CLI only maps `openrouter/`, `google/`, `openai/`, and `anthropic/`
prefixes to keys. Fix the provider string or use the library directly with
your own `DSPy.configure`.

### "OPENROUTER_API_KEY is not set (required by DSPY_PROVIDER=...)"

Set the key matching your provider prefix in `.env`.

### "[ERROR] LLM provider error: ..."

The provider rejected the call (rate limit, upstream outage). These are
transient — retry shortly or switch `DSPY_PROVIDER` to another model.

### "[ERROR] Database connection failed for ..."

Update `DATABASE_URL` in `.env`:

```bash
# Default (Unix socket)
DATABASE_URL=postgresql:///sfl_compiler_dev

# With host/port
DATABASE_URL=postgresql://user@localhost:5432/sfl_compiler_dev
```

### All tenor values are 0.5

The report's Data Quality section tells you directly: if 100% of clauses are
fallback/stub, Pass 2 didn't run (missing key, failing provider, or
`--pass1-only`). Check the per-turn console output for `DEFAULTED` labels and
`[WARN]` lines identifying the failing clauses.

### "No stored clauses matched" on context queries

Either nothing has been ingested (`sfl-analyze documentation <path> --store`
first), or the query/filters are too restrictive — try a shorter query with
content words that actually appear in the corpus, and loosen stance filters.

## Advanced Usage

### Batch processing

```bash
for file in conversations/*.jsonl; do
  bundle exec sfl-analyze conversation \
    "$file" \
    --output-dir "./output/$(basename "$file" .jsonl)"
done
```

### Pass 1 only (no LLM)

```bash
bundle exec sfl-analyze conversation /path/to/conversation.jsonl --pass1-only
```

Extracts process types and participants without any LLM cost. Interpersonal
values are placeholders marked `stub`, and the report says so.

### Library-level composition

For bespoke analyses, compose the same objects the CLI uses —
`Bootstrap.call` → `Pipeline` → `Analysis::ConversationAnalyzer` /
`Analysis::DocumentationAnalyzer` / `ContextSynthesizer` →
`Formatters::ReportWriter`. See `lib/sfl/compiler/cli.rb` for the wiring and
README's Library Usage section for examples.
