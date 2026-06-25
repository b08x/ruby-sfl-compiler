# SFL Compiler Usage Guide

The `sfl-analyze` CLI has four subcommands forming one workflow: analyze
conversations or documentation, optionally **ingest** documentation into
PostgreSQL, then **query** the stored corpus with stance filters, and finally
**narrate** the result.

## Quick Start

### 1. Configure Environment

Edit `.env` and set a provider plus its matching key. The CLI supports four
provider prefixes and resolves the key automatically:

```bash
# OpenRouter (one key, many models)
DSPY_PROVIDER=openrouter/mistralai/mistral-7b-instruct
OPENROUTER_API_KEY=your-openrouter-key-here

# OR Google Gemini
DSPY_PROVIDER=google/gemini-2.0-flash-exp
GOOGLE_API_KEY=your-google-key-here

# OR OpenAI
DSPY_PROVIDER=openai/gpt-4o-mini
OPENAI_API_KEY=your-openai-key-here

# OR Anthropic
DSPY_PROVIDER=anthropic/claude-3-5-sonnet-20241022
ANTHROPIC_API_KEY=your-anthropic-key-here
```

Any other prefix makes the CLI exit with
`Unsupported DSPY_PROVIDER: ...`. (The library itself accepts anything
DSPy.rb supports — configure `DSPy.configure { |c| c.lm = ... }` yourself and
skip `Bootstrap` — but the CLI's provider map is those four.)

For semantic search and `context` queries you also need Ollama running with
`embeddinggemma:latest` model (configure `OLLAMA_BASE_URL` and `EMBEDDING_MODEL`
in `.env`). Without it, `--store` still persists clauses (no embeddings) and
retrieval works keyword-only.

### Observability (optional)

Setting `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY` in `.env` traces every
LLM call (DSPy modules and RubyLLM embedding calls) to Langfuse via
OpenTelemetry — no further setup needed. `LANGFUSE_HOST` defaults to
`https://cloud.langfuse.com`; set it for a self-hosted instance.

```bash
LANGFUSE_PUBLIC_KEY=your-public-key
LANGFUSE_SECRET_KEY=your-secret-key
LANGFUSE_HOST=https://cloud.langfuse.com   # or your self-hosted URL
```

These vars must be set in `.env` (or already exported) **before** the CLI
starts — `exe/sfl-analyze` loads `.env` before requiring anything else
specifically so this works; see `lib/sfl/compiler/bootstrap.rb`'s
`configure_observability` comments if wiring tracing into a new entry point.

Before opening a real trace session, the CLI runs `LangfuseReachability`
to verify the endpoint is reachable:

- keys unset → tracing silently skipped (no network call)
- reachable → tracing enabled
- unreachable + interactive TTY → prompt to skip or cancel
- unreachable + non-TTY → tracing skipped, run continues

Every subcommand accepts `--disable-tracing` to skip this regardless of what
`.env` has set.

### 2. Run an Analysis

```bash
# Conversation (sequential by default)
bundle exec sfl-analyze conversation /path/to/conversation.jsonl --output-dir ./output

# Conversation (parallel via Sidekiq/Gush)
bundle exec sfl-analyze conversation /path/to/conversation.jsonl --output-dir ./output --live

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

### 5. Narrative Reports

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
`narrate`ing one of those fails fast with `[ERROR] Report JSON has no turns
array — it predates narrative support. Re-run the analysis to regenerate it.`
Re-run `conversation`/`documentation` to produce a JSON with `turns`, then
`narrate` that.

## Parallel Conversation Processing

For large conversations, the `conversation --live` command distributes turns
across Sidekiq workers via Gush instead of compiling each turn in-process. Each
`CompileTurnJob` runs in its own process with its own Python interpreter, which
avoids the PyCall GIL deadlock that can occur when spaCy and Ruby threads share
runtime state.

```bash
# Start Redis first, then run with --live
redis-server
bundle exec sfl-analyze conversation chat.jsonl --output-dir ./output --live
```

If `REDIS_URL` is unset, it defaults to `redis://localhost:6379/0`. A typical
full local configuration might look like:

```bash
REDIS_URL=redis://localhost:6379/0
DATABASE_URL=postgresql:///sfl_compiler_dev
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

### "Redis connection refused" with `--live`

The parallel workflow needs Redis. Start it (`redis-server`) or set
`REDIS_URL` to a reachable instance. Omit `--live` to run the conversation
sequentially without Redis.

### "Langfuse unreachable"

If you set Langfuse keys but the endpoint is not reachable, the CLI prompts in
interactive mode. Answer `y` to continue without tracing, or `n` to cancel. In
non-interactive mode it continues silently without tracing. Use
`--disable-tracing` to skip the prompt entirely.

## Cross-Document Reasoning

`SFL::Compiler::CrossDocumentGraph` builds a small query-time graph across stored
documents so you can ask questions that span more than one source. It works
like `ContextSynthesizer`, but before generating an answer it resolves entity
and clause nodes across documents and ranks them by combined semantic +
keyword relevance.

```ruby
require "sfl/compiler/bootstrap"
Bootstrap.call

graph = SFL::Compiler::CrossDocumentGraph.new
answer = graph.answer(
  "How do deployment practices differ between the API and web docs?",
  min_modality: 0.6,
  limit: 8
)
puts answer.text
puts answer.confidence
```

Returned answers include the same confidence score and cited clause list as the
`context` CLI command; clauses actually used in the synthesis are marked `*`.

## Sprint Workflow

`SFL::Compiler::Workflows::SprintWorkflow` lets you plan and execute a batch of
analyses as one unit. Give it a list of paths; it runs the pipeline for each,
collects reports, and returns a single summary.

```ruby
require "sfl/compiler/bootstrap"
require "sfl/compiler/workflows/sprint_workflow"
Bootstrap.call(require_jobs: true)   # omit for inline execution

workflow = SFL::Compiler::Workflows::SprintWorkflow.new
result = workflow.run(
  paths: Dir["sprint-*.jsonl"],
  command: :conversation,
  output_dir: "./output/sprint-#{Date.today}",
  narrative: true
)

puts "#{result.reports.size} reports written"
result.failures.each { |f| warn "#{f[:path]}: #{f[:error]}" }
```

Failures are captured per item so one bad file does not abort the whole batch.
Use `Bootstrap.call(require_jobs: true)` to distribute work across Sidekiq/Gush
when Redis is available.

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

When you need Sidekiq/Gush, `Bootstrap.call(require_jobs: true)` wires the
queue adapter and Redis. Without that, workflows enqueue jobs inline for
local testing.
