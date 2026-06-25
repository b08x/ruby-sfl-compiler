# SFL Compiler — Agent Guide

## What This Is

A Ruby gem (`sfl-compiler`, v0.1.0) that compiles natural language into structured SFL (Systemic Functional Linguistics) annotations using a two-pass pipeline. Pass 1 extracts syntactic structure and ideational content via spaCy; Pass 2 annotates interpersonal features (mood, modality, tenor) via an LLM through DSPy.rb. Output is stored in PostgreSQL + pgvector for hybrid retrieval with scalar filtering on rhetorical stance.

## Environment & Prerequisites

- **Ruby** >= 3.3.0 (tested on 3.4.0)
- **PostgreSQL** with `vector` and `pg_trgm` extensions
- **Python** spaCy with `en_core_web_sm` model (`pip install spacy && python -m spacy download en_core_web_sm`)
- **`.env` file** in project root (copy from `.env.example`). Must set `DATABASE_URL`, `DSPY_PROVIDER`, and at least one API key.

## Essential Commands

```bash
# Install dependencies
bundle install

# Run the full test suite
bundle exec rspec spec/ --format documentation

# Run a single spec
bundle exec rspec spec/sfl/compiler/types_spec.rb

# Lint
bundle exec rubocop

# Process NotebookLM sources through the pipeline
bundle exec ruby scripts/parse_metacognitive_coprocessor.rb

# Pass 1 only (no LLM calls)
PASS=1 bundle exec ruby scripts/parse_metacognitive_coprocessor.rb

# Dry run — print sections without compiling
DRY_RUN=1 bundle exec ruby scripts/parse_metacognitive_coprocessor.rb

# Single file
FILE=lsd-brain-network-collapse.md bundle exec ruby scripts/parse_metacognitive_coprocessor.rb

# Analyze a conversation / documentation / query stored context
bundle exec sfl-analyze conversation conversation.jsonl --output-dir ./output/latest
bundle exec sfl-analyze documentation docs/ --store
bundle exec sfl-analyze context "what is the main claim?" --min-modality 0.7

# Sidekiq worker for the Gush conversation analysis workflow (requires Redis)
# Not a Rails app, so -r must point at a boot file or Sidekiq exits immediately
# asking for one. The leading ./ is required — Sidekiq's -r loads the path via
# Kernel#require, which (unlike #load) does not search cwd for a bare relative
# path, only $LOAD_PATH. Without ./ this fails with LoadError from inside
# sidekiq/cli.rb, even though the file exists right there.
bundle exec sidekiq -q gush -r ./lib/sfl/compiler/sidekiq_boot.rb
```

## Architecture

```
exe/sfl-analyze → CLI → Bootstrap (.env, DSPy, DB)
                   ↓
MarkdownLoader → Pipeline → PassOneEngine (spaCy) → IdeationalExtractor (rule-based)
                                                         ↓
                                                    PassTwoEngine (DSPy.rb + LLM, batched)
                                                         ↓
                              ClauseRepository + EmbeddingRepository (PostgreSQL)
                                                         ↓
                              HybridRetriever (RRF: semantic vector + keyword full-text)
                                                         ↓                    ↓
   Analysis (ConversationAnalyzer, DocumentationAnalyzer,            ContextSynthesizer
             TenorTracker, SpeakerProfiler, CorrelationAnalyzer)     (grounded LLM answer
                                                         ↓            with citations)
                              Formatters (CSV, JSON, Markdown) + ReportWriter
```

Strict layering: **CLI** owns argv/printing/exit codes; **Bootstrap** owns env
wiring (the only ENV reader); **analyzers are UI-agnostic** (no puts/exit/ENV,
progress via injectable `on_progress` callback) so a TUI can reuse them.

### Pass 1 — SyntacticEngine + IdeationalExtractor
- `lib/sfl/compiler/pass_one/pass_one_engine.rb`: Calls `Spacy::Language.new(model).read(text)` **once per section** (one PyCall round-trip). Sentence boundaries from `doc.sents`. Output: `Array<SyntacticClause>` with full token-level annotations.
- `lib/sfl/compiler/pass_one/ideational_extractor.rb`: Pure Ruby, no LLM. Lemma-based transitivity classification via hardcoded verb lists (`mental_verb?`, `relational_verb?`, `verbal_verb?`, `behavioral_verb?`). Maps spaCy dependency labels to SFL roles (`nsubj`→Actor, `dobj`→Goal, etc.).

### Pass 2 — SemanticAnnotator
- `lib/sfl/compiler/pass_two/pass_two_engine.rb`: DSPy.rb `ChainOfThought`. Two paths: `annotate` (single clause, `SFLSignature`) and `annotate_batch` (the default via `Pipeline#compile`, `SFLBatchSignature` — ~12 clauses per LLM call on a 4-thread pool, `SFL_BATCH_SIZE`/`SFL_CONCURRENCY` env overrides). Batch responses are index-keyed; order is never trusted.
- **Degradation ladder**: transient chunk failure → one retry; persistent chunk failure → defaults for that chunk; missing/invalid annotation → defaults for that clause only. All defaults marked `annotation_source: "fallback"` and `[WARN]`ed to `$stderr`. Pass 1 data is always preserved.
- **Circuit breaker**: Default is a no-op pass-through (`lambda { |&block| block.call }`). Real one not injected yet.

### Storage
- `lib/sfl/compiler/storage/database.rb`: `Database.connect` (Sequel), `Database.setup_extensions` (vector + pg_trgm), `Migrator.run_all` (creates 4 tables).
- **4 tables**: `clauses`, `ideational_payloads`, `interpersonal_payloads`, `embeddings`
- **Key indices**: Scalar on `interpersonal_payloads(mood, modality_weight, tenor)`, ivfflat cosine on `embeddings(embedding)`, GIN on `clauses(tokens)` and full-text on `clauses(text)`.
- `clause_repository.rb`: `store`, `find`, `find_by_interpersonal`, `find_by_process_type`.

### Retrieval & Synthesis
- `lib/sfl/compiler/retrieval/hybrid_retriever.rb`: Semantic (`<=>` cosine) + keyword (`to_tsvector @@ plainto_tsquery`) merged with RRF (k=60). Scalar filters applied post-merge in Ruby (N+1 pattern — fine for small result sets, needs SQL join rewrite at scale). Keyword search ANDs all query terms ('simple' config, stopwords kept).
- `lib/sfl/compiler/retrieval/context_synthesizer.rb`: `ContextSynthesizer` — retrieve → numbered SFL-annotated evidence → `SynthesisSignature` ChainOfThought → `Types::SynthesisResult` (answer, cited clause ids, confidence). Citations come back as evidence numbers and are bounds-checked; out-of-range numbers dropped. Empty retrieval short-circuits without an LLM call; malformed LLM output degrades to evidence-only with `[WARN]`.

### Entry Points
- `lib/sfl/compiler/bootstrap.rb`: `Bootstrap.call(require_db:, require_llm:, env:, load_dotenv:)` — the ONLY ENV reader. Provider prefix → API key map (openrouter/google/openai/anthropic); raises `BootstrapError` on unsupported prefix, missing key, or DB connection failure.
- `lib/sfl/compiler/cli.rb` + `exe/sfl-analyze`: subcommands `conversation`, `documentation [--store]`, `context` with stance-filter flags, and `narrate <analysis.json>`. `CLI.parse` is a pure function (tested); `run_*` methods wire Bootstrap → analyzers (live-verified, not unit-tested). `conversation`/`documentation` accept `--narrative` to run `NarrativeGenerator` best-effort after the CSV/JSON/MD trio (failure → `[WARN]`, exit 0 unaffected); `narrate` reads a written report JSON (requires its `turns` array — re-run to regenerate older JSONs) and writes `narrative_report.md` via one LLM call, exiting 1 on any error.

### Analysis
- `lib/sfl/compiler/analysis/conversation_analyzer.rb`: JSONL → per-turn compile → `Types::AnalysisResult`. Injected pipeline, `pass_one_only:` option (stubs marked `"stub"`), `on_progress` callback.
- `lib/sfl/compiler/analysis/documentation_analyzer.rb`: markdown file/dir → sections mapped onto turns (speaker = heading, timestamp = mtime) so SpeakerProfiler/formatters apply; `store: true` deletes each section's stable `document_id` first (idempotent re-ingest), stores clauses + embeddings.
- `lib/sfl/compiler/analysis/tenor_tracker.rb`: Tenor shift detection between consecutive turns (threshold default 0.15). **Mutates** the `@turns` array in-place — callers beware.
- `lib/sfl/compiler/analysis/speaker_profiler.rb`: Per-speaker aggregates (tenor range, variance, mood distribution, dominant processes).
- `lib/sfl/compiler/analysis/correlation_analyzer.rb`: Correlates process types with avg tenor/modality.

### Formatters
- All inherit from `BaseFormatter#render` → `BaseFormatter#write_to(path)`.
- CSV: headers + turn-by-turn rows with truncated messages (columns fixed at turn_id/speaker — machine schema).
- JSON: metadata (including `annotation_coverage`: llm/fallback/stub counts + defaulted %), speaker_profiles, tenor_timeline, field_evolution, correlations, insights.
- Markdown: tables for profiles and correlations, numbered insights list. Renders a **⚠️ Data Quality** section when any clause is non-llm sourced. Labels parameterized via `metadata[:unit_label]`/`[:actor_label]`/`[:actors_list_label]` (defaults Turn/Speaker/Speakers; DocumentationAnalyzer sets Section/Section/Headings).
- `report_writer.rb`: `ReportWriter.write(result, dir)` → writes the CSV/JSON/MD trio, returns paths.

### MarkdownLoader
- `lib/sfl/compiler/markdown_loader.rb`: Chunks by ATX heading via Inkmark. Strips YAML frontmatter, drops fenced code blocks, renders to HTML then strips tags, normalizes through PragmaticTokenizer. Emits `Section` structs with `document_id` = `"file_id#heading_slug"`.

### Parallel Conversation Analysis (Gush/Sidekiq) — library-level, no CLI wiring yet
- `lib/sfl/compiler/workflows/conversation_analysis_workflow.rb`: a `Gush::Workflow` that decomposes the same work `ConversationAnalyzer#analyze` does sequentially into a parallel DAG — one `CompileTurnJob` per turn (no dependency between them, so they run concurrently across however many Sidekiq workers are up), fanning into one `ReduceTurnsJob`.
- **Why this exists**: Pass 1 calls spaCy through PyCall, and [PyCall's own docs state it does not support multi-threaded use](https://github.com/red-data-tools/pycall.rb) — calling it from a `Thread.new` inside one process segfaults (this is exactly what's wrong with the TUI's `--live` flag today, see `lib/sfl/compiler/tui/batch_app.rb` / `.claude/skills/sfl-tui/references/known-issues.md`). Running each turn in its own Sidekiq **process** instead of a thread sidesteps the restriction entirely — each worker process gets its own Python interpreter.
- **Scope today**: only the `topics: nil` path (no topic-modeling pre-pass); `DocumentationAnalyzer` has no equivalent workflow yet; `ReduceTurnsJob#output` forwards `metadata`/`insights` only, not the full `speaker_profiles`/`tenor_timeline`/`correlations`/`key_moments` — none of this is wired into `sfl-analyze`'s CLI/TUI yet. See the trackboi track `tui-overhaul-gush-sidekiq-backed-pycall-safe` for the rebuild-the-TUI-on-this follow-up work.
- **Running it**: needs Redis (`REDIS_URL`, defaults to `redis://localhost:6379`) and a Sidekiq worker (`bundle exec sidekiq -q gush -r ./lib/sfl/compiler/sidekiq_boot.rb`) — see Essential Commands. `ConversationAnalysisWorkflow.create(jsonl_path); flow.start!; flow.reload; flow.status` per Gush's own API.

## Key File Map

```
lib/sfl/compiler.rb                  # Zeitwerk loader, Configuration, error classes, module setup
lib/sfl/compiler/version.rb          # VERSION = "0.1.0"
lib/sfl/compiler/types.rb            # All Dry::Struct types (constrained enums, 0-1 floats)
lib/sfl/compiler/bootstrap.rb        # Env wiring: .env → config, DSPy LM, DB connect (only ENV reader)
lib/sfl/compiler/cli.rb              # sfl-analyze subcommand parse + run wiring
lib/sfl/compiler/pipeline.rb         # Orchestrator: compile(), compile_pass_one(), compile_pass_two()
lib/sfl/compiler/pass_one/
  pass_one_engine.rb                 # spaCy wrapper → SyntacticClause[]
  ideational_extractor.rb            # Rule-based transitivity classification
lib/sfl/compiler/pass_two/
  pass_two_engine.rb                 # DSPy.rb ChainOfThought, batched annotate_batch → InterpersonalPayload
lib/sfl/compiler/storage/
  database.rb                        # Sequel.connect, extensions, Migrator (4 tables + indices)
  clause_repository.rb               # Store/find/delete_by_document with scalar interpersonal filters
  embedding_repository.rb            # pgvector nearest-neighbors
lib/sfl/compiler/retrieval/
  hybrid_retriever.rb                # RRF merge + scalar filter + Embedder class
  context_synthesizer.rb             # Retrieval → cited LLM synthesis (SynthesisSignature, SFLSynthesizer)
lib/sfl/compiler/analysis.rb         # MANIFEST: require_relative for every analysis/ file
lib/sfl/compiler/analysis/
  conversation_analyzer.rb           # JSONL conversation → AnalysisResult
  documentation_analyzer.rb          # Markdown sections-as-turns → AnalysisResult, --store ingest
  tenor_tracker.rb, speaker_profiler.rb, correlation_analyzer.rb
  narrative_generator.rb             # NarrativeGenerator + Digest + NarrativeSignature → Types::NarrativeReport
lib/sfl/compiler/formatters.rb       # MANIFEST: require_relative for every formatters/ file
lib/sfl/compiler/formatters/
  base/csv/json/markdown formatters + report_writer.rb
  narrative_formatter.rb             # NarrativeReport → narrative_report.md
lib/sfl/compiler/markdown_loader.rb  # ATX-heading chunks → clean prose sections
lib/sfl/compiler/llm_tools/
  theme_rheme_extractor.rb           # RubyLLM Tool for Theme/Rheme (experimental)
lib/sfl/compiler/jobs/
  compile_turn_job.rb                # Gush::Job: one turn's Pass 1+2 compile, runs in a Sidekiq worker process
  reduce_turns_job.rb                # Gush::Job: fan-in — rebuilds turns from payloads, runs ConversationAnalyzer#build_result
lib/sfl/compiler/workflows/
  conversation_analysis_workflow.rb  # Gush::Workflow: fans out CompileTurnJob per turn, fans into ReduceTurnsJob
lib/sfl/compiler/sidekiq_boot.rb     # `-r` target for `bundle exec sidekiq -q gush`; wires Bootstrap(require_jobs: true)
lib/sfl-compiler.rb                  # Top-level require
exe/sfl-analyze                      # CLI binstub (gemspec executable)
scripts/parse_metacognitive_coprocessor.rb  # NotebookLM batch processing script
```

## Data Types (Dry::Struct)

All in `lib/sfl/compiler/types.rb`. Key ones:
- `SyntacticToken`: text, lemma, pos, tag, dep, head_index, morphology, index
- `SyntacticClause`: id, text, tokens[], root_index, sentence_index, document_id
- `IdeationalPayload`: clause_id, process_type (enum), participants[], circumstances[], raw_transitivity
- `InterpersonalPayload`: clause_id, mood (enum), modality_weight (0-1), tenor (0-1), speaker_attitude, reasoning, annotation_source (enum, default "llm")
- `AnnotatedClause`: id, text, syntactic, ideational, interpersonal, document_id, compiled_at
- `SynthesisResult`: query, answer (nilable), cited_clause_ids[], clauses[], retrieved_count, confidence (nilable)
- `ConversationTurn`: turn_id, speaker, timestamp, message_text, clauses[], avg_tenor, avg_modality, dominant_mood, process_types, participants, tenor_shift
- `SpeakerProfile`: speaker_name, turn_count, avg_tenor, tenor_range, tenor_variance, avg_modality, mood_distribution, dominant_processes
- `AnalysisResult`: metadata, turns[], speaker_profiles{}, tenor_timeline, field_evolution, correlations, insights

Enums: `process_type` ∈ {material, mental, relational, verbal, behavioral, existential}, `mood` ∈ {declarative, interrogative, imperative, exclamative}, `annotation_source` ∈ {llm, fallback, stub}

## Configuration

```ruby
SFL::Compiler.configure do |c|
  c.database_url   = "postgresql:///sfl_compiler_dev"
  c.spacy_model    = "en_core_web_sm"
  c.dspy_provider  = "openrouter/mistralai/mistral-7b-instruct"
end

# DSPy.rb must be configured separately:
DSPy.configure do |c|
  c.lm = DSPy::LM.new("openrouter/mistralai/mistral-7b-instruct",
    api_key: ENV["OPENROUTER_API_KEY"],
    structured_outputs: true)
end
```

Environment variables (from `.env`): `DATABASE_URL`, `DSPY_PROVIDER`, `OPENROUTER_API_KEY` / `GOOGLE_API_KEY` / `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`, `SPACY_MODEL`, `LOG_LEVEL`, `REDIS_URL` (Gush workflow state; only read when `Bootstrap.call(require_jobs: true)`).

## Gotchas & Non-Obvious Patterns

1. **spaCy via PyCall**: `ruby-spacy` shells out to Python. If the Python env doesn't have spacy + model, Pass 1 raises `PassOneError` with no fallback.

2. **Circuit breaker is a no-op**: `PassTwoEngine#default_circuit_breaker` is `lambda { |&block| block.call }`. The `rescue CircuitBreaker::CircuitBrokenException` clause in `annotate_interpersonal` will never trigger until a real breaker is injected.

3. **TenorTracker mutates in-place**: `calculate_shifts` replaces structs in the `@turns` array rather than returning a new array. Callers passing their only reference will see it mutated.

4. **Keyword search doesn't join tables**: `keyword_search` queries `clauses` alone. Scalar filtering happens in Ruby after the RRF merge (N+1 queries in `apply_filters`). Fine for small sets, needs SQL join at scale.

5. **Pass 2 defaults are provenance-marked, not silent**: failed/skipped annotations carry `annotation_source: "fallback"`/`"stub"`, print `[WARN]` to `$stderr`, and surface as the markdown report's Data Quality section + JSON `annotation_coverage`. A report full of 0.5s announces itself.

6. **`mean` is duplicated 4×**: SpeakerProfiler, CorrelationAnalyzer, ConversationAnalyzer, DocumentationAnalyzer (plus duplicated `report_progress`/`timeline`/`field_evolution` between the two analyzers). Extract a shared `Analysis::Aggregations` mixin before adding another analyzer — see `docs/status/BACKLOG_FIXES.md`.

7. **Hardcoded paths in main script**: `scripts/parse_metacognitive_coprocessor.rb` has `../../../Notebook/NotebookLM/metacognitive-coprocessor/` hardcoded. Use `FILE=...` env var for other files.

8. **Embedding dimension is 768**: Uses Ollama `embeddinggemma:latest` (requires `OLLAMA_BASE_URL` and `EMBEDDING_MODEL` in `.env`). The `Embedder` class configures RubyLLM to use the Ollama provider. Change the column type in `create_embeddings_table` if using a different model.

9. **Zeitwerk collapsing + manifest split**: `pass_one/`, `pass_two/`, `storage/`, `retrieval/` files define FLAT constants at `SFL::Compiler` (e.g., `PassOneEngine`, `HybridRetriever`, `ContextSynthesizer`) and autoload normally. But `analysis/` and `formatters/` files use NESTED modules (`Analysis::TenorTracker`, `Formatters::CSVFormatter`) and only load via explicit `require_relative` lines in the manifest files `lib/sfl/compiler/analysis.rb` / `lib/sfl/compiler/formatters.rb` — **a new file in those two dirs MUST be added to its manifest** or you get `uninitialized constant`.

10. **CLI keyword search ANDs all terms**: `plainto_tsquery('simple', ...)` keeps stopwords and requires every word to match, so `context` queries phrased as full questions often miss; without stored embeddings (no `OPENAI_API_KEY`), retrieval is keyword-only.

11. **`bundle exec` and exe/**: the Gemfile doesn't use `gemspec`, so `bundle exec` alone doesn't put `lib/` on the load path — `exe/sfl-analyze` unshifts its sibling `lib/` itself. Run specs with `bin/rspec` if the `bundle exec rspec` binstub misbehaves.

12. **PyCall is single-thread only — never call Pass 1 from a `Thread.new`**: any code path that runs `PassOneEngine`/spaCy off the main thread of a process that's also doing other things on other threads risks a real `[BUG] Segmentation fault` (confirmed in the TUI's `--live` flag — see `.claude/skills/sfl-tui/references/known-issues.md`). The Gush-based `jobs/`/`workflows/` files exist specifically to get parallelism via separate OS *processes* instead — don't "fix" a slow Pass 1 by wrapping it in a Ruby thread.

13. **`jobs/`/`workflows/` collapse like `pass_one/`/`pass_two/`**: same flat-constant Zeitwerk convention as gotcha #9 (`SFL::Compiler::CompileTurnJob`, not `SFL::Compiler::Jobs::CompileTurnJob`) — `lib/sfl/compiler.rb` has a `loader.collapse` line for each. `sidekiq -r` loads files via `Kernel#require`, which doesn't search `cwd` for a bare relative path — `bundle exec sidekiq -q gush -r lib/sfl/compiler/sidekiq_boot.rb` (no `./`) raises `LoadError` even though the file is right there; always pass `-r ./lib/...`.

## Test Structure

- `spec/spec_helper.rb`: Bundler setup, RSpec config (random order, focus filter, verified doubles).
- **Unit specs** (all green, no DB/LLM required): types, pipeline, pass_two_engine (batching/fallback/retry), bootstrap, cli (parse only), conversation_analyzer, documentation_analyzer, context_synthesizer, clause_repository (delete_by_document), hybrid_retriever, markdown_loader, tenor_tracker, speaker_profiler, correlation_analyzer, all four formatters/report_writer.
- **Known broken**: `spec/integration/` — calls `integration_env_ready?` from inside examples (RSpec API misuse) and references the deleted template script. Exclude it: `bundle exec rspec spec/ --exclude-pattern "integration/**/*"`.
- **Missing specs**: ThemeRhemeExtractor (experimental); CLI `run_*` paths are live-verified rather than unit-tested (by design — they need DB + LLM).
- **Test data**: `spec/fixtures/conversations/sample.jsonl` — 5-turn conversation.

## Experiments

The `experiments/` directory contains throwaway scripts validating SFL theories. Results in `experiments/RESULTS.md`: 5/6 theories validated. FCA, ID3, cohesion correlations, and DSPy Theme/Rheme all validated. spaCy-only Theme/Rheme failed (16.7% accuracy). These scripts are intentionally <100 lines, no error handling, no abstraction.

## Claude Code / OpenCode Integration

- **Skill**: `.claude/skills/sfl-analyze/SKILL.md` — composes `sfl-analyze` CLI invocations for conversation/documentation/context analyses.
- **Agent**: `.claude/agents/sfl-analyzer.md` — expert agent for SFL analysis tasks.
- **OpenCode plugin**: `.opencode/plugins/graphify.js` — graph visualization plugin.

## Documentation Index

- **Guides:** `docs/guides/QUICKSTART.md`, `docs/guides/USAGE.md`
- **Planning:** `docs/planning/NOTEBOOK_ANALYSIS_PLAN.md`, `docs/planning/RESEARCH_APPLICATION_PLAN.md`
- **Status:** `docs/status/BACKLOG_FIXES.md`, `docs/status/KNOWN_ISSUES.md`, `docs/status/SESSION_SUMMARY.md`, `docs/status/DEBUGGING_SESSION.md`
- **Architecture & Theory:** `docs/geb-lens-on-sfl-compiler.md`, `docs/knowledge-base.md`, `docs/poignant-guide-to-sfl-compiler.md`
- **Articles:** `docs/articles/from-graph-to-story.md`
