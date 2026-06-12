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
bundle exec sfl-analyze conversation conversation.jsonl --output-dir ./output
bundle exec sfl-analyze documentation docs/ --store
bundle exec sfl-analyze context "what is the main claim?" --min-modality 0.7
```

## Architecture

```
MarkdownLoader → Pipeline → PassOneEngine (spaCy) → IdeationalExtractor (rule-based)
                                                         ↓
                                                    PassTwoEngine (DSPy.rb + LLM)
                                                         ↓
                              ClauseRepository + EmbeddingRepository (PostgreSQL)
                                                         ↓
                              HybridRetriever (RRF: semantic vector + keyword full-text)
                                                         ↓
                              Analysis (TenorTracker, SpeakerProfiler, CorrelationAnalyzer)
                                                         ↓
                              Formatters (CSV, JSON, Markdown)
```

### Pass 1 — SyntacticEngine + IdeationalExtractor
- `lib/sfl/compiler/pass_one/pass_one_engine.rb`: Calls `Spacy::Language.new(model).read(text)` **once per section** (one PyCall round-trip). Sentence boundaries from `doc.sents`. Output: `Array<SyntacticClause>` with full token-level annotations.
- `lib/sfl/compiler/pass_one/ideational_extractor.rb`: Pure Ruby, no LLM. Lemma-based transitivity classification via hardcoded verb lists (`mental_verb?`, `relational_verb?`, `verbal_verb?`, `behavioral_verb?`). Maps spaCy dependency labels to SFL roles (`nsubj`→Actor, `dobj`→Goal, etc.).

### Pass 2 — SemanticAnnotator
- `lib/sfl/compiler/pass_two/pass_two_engine.rb`: DSPy.rb `ChainOfThought` with `SFLSignature`. Gets syntactic context (root verb, process type, participants, POS/dep sequences) and returns mood, modality_weight (0-1), tenor (0-1), speaker_attitude, reasoning.
- **Circuit breaker**: Default is a no-op pass-through (`lambda { |&block| block.call }`). Real one not injected yet.
- **On failure**: Logs `[WARN]` to `$stderr`, falls back to defaults (modality=0.5, tenor=0.5, mood=declarative). Pass 1 data is always preserved.

### Storage
- `lib/sfl/compiler/storage/database.rb`: `Database.connect` (Sequel), `Database.setup_extensions` (vector + pg_trgm), `Migrator.run_all` (creates 4 tables).
- **4 tables**: `clauses`, `ideational_payloads`, `interpersonal_payloads`, `embeddings`
- **Key indices**: Scalar on `interpersonal_payloads(mood, modality_weight, tenor)`, ivfflat cosine on `embeddings(embedding)`, GIN on `clauses(tokens)` and full-text on `clauses(text)`.
- `clause_repository.rb`: `store`, `find`, `find_by_interpersonal`, `find_by_process_type`.

### Retrieval
- `lib/sfl/compiler/retrieval/hybrid_retriever.rb`: Semantic (`<=>` cosine) + keyword (`to_tsvector @@ plainto_tsquery`) merged with RRF (k=60). Scalar filters applied post-merge in Ruby (N+1 pattern — fine for small result sets, needs SQL join rewrite at scale).

### Conversation Analysis
- `lib/sfl/compiler/analysis/tenor_tracker.rb`: Tenor shift detection between consecutive turns (threshold default 0.15). **Mutates** the `@turns` array in-place — callers beware.
- `lib/sfl/compiler/analysis/speaker_profiler.rb`: Per-speaker aggregates (tenor range, variance, mood distribution, dominant processes).
- `lib/sfl/compiler/analysis/correlation_analyzer.rb`: Correlates process types with avg tenor/modality.

### Formatters
- All inherit from `BaseFormatter#render` → `BaseFormatter#write_to(path)`.
- CSV: headers + turn-by-turn rows with truncated messages.
- JSON: metadata, speaker_profiles, tenor_timeline, field_evolution, correlations, insights.
- Markdown: tables for profiles and correlations, numbered insights list.

### MarkdownLoader
- `lib/sfl/compiler/markdown_loader.rb`: Chunks by ATX heading via Inkmark. Strips YAML frontmatter, drops fenced code blocks, renders to HTML then strips tags, normalizes through PragmaticTokenizer. Emits `Section` structs with `document_id` = `"file_id#heading_slug"`.

## Key File Map

```
lib/sfl/compiler.rb                  # Zeitwerk loader, Configuration, error classes, module setup
lib/sfl/compiler/version.rb          # VERSION = "0.1.0"
lib/sfl/compiler/types.rb            # All Dry::Struct types (constrained enums, 0-1 floats)
lib/sfl/compiler/pipeline.rb         # Orchestrator: compile(), compile_pass_one(), compile_pass_two()
lib/sfl/compiler/pass_one/
  pass_one_engine.rb                 # spaCy wrapper → SyntacticClause[]
  ideational_extractor.rb            # Rule-based transitivity classification
lib/sfl/compiler/pass_two/
  pass_two_engine.rb                 # DSPy.rb ChainOfThought → InterpersonalPayload
lib/sfl/compiler/storage/
  database.rb                        # Sequel.connect, extensions, Migrator (4 tables + indices)
  clause_repository.rb               # Store/find with scalar interpersonal filters
  embedding_repository.rb            # pgvector nearest-neighbors
lib/sfl/compiler/retrieval/
  hybrid_retriever.rb                # RRF merge + scalar filter + Embedder class
lib/sfl/compiler/markdown_loader.rb  # ATX-heading chunks → clean prose sections
lib/sfl/compiler/llm_tools/
  theme_rheme_extractor.rb           # RubyLLM Tool for Theme/Rheme (experimental)
lib/sfl-compiler.rb                  # Top-level require
scripts/parse_metacognitive_coprocessor.rb  # Main batch processing script
```

## Data Types (Dry::Struct)

All in `lib/sfl/compiler/types.rb`. Key ones:
- `SyntacticToken`: text, lemma, pos, tag, dep, head_index, morphology, index
- `SyntacticClause`: id, text, tokens[], root_index, sentence_index, document_id
- `IdeationalPayload`: clause_id, process_type (enum), participants[], circumstances[], raw_transitivity
- `InterpersonalPayload`: clause_id, mood (enum), modality_weight (0-1), tenor (0-1), speaker_attitude, reasoning
- `AnnotatedClause`: id, text, syntactic, ideational, interpersonal, document_id, compiled_at
- `ConversationTurn`: turn_id, speaker, timestamp, message_text, clauses[], avg_tenor, avg_modality, dominant_mood, process_types, participants, tenor_shift
- `SpeakerProfile`: speaker_name, turn_count, avg_tenor, tenor_range, tenor_variance, avg_modality, mood_distribution, dominant_processes
- `AnalysisResult`: metadata, turns[], speaker_profiles{}, tenor_timeline, field_evolution, correlations, insights

Enums: `process_type` ∈ {material, mental, relational, verbal, behavioral, existential}, `mood` ∈ {declarative, interrogative, imperative, exclamative}

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

Environment variables (from `.env`): `DATABASE_URL`, `DSPY_PROVIDER`, `OPENROUTER_API_KEY` / `GOOGLE_API_KEY` / `OPENAI_API_KEY` / `ANTHROPIC_API_KEY`, `SPACY_MODEL`, `LOG_LEVEL`.

## Gotchas & Non-Obvious Patterns

1. **spaCy via PyCall**: `ruby-spacy` shells out to Python. If the Python env doesn't have spacy + model, Pass 1 raises `PassOneError` with no fallback.

2. **Circuit breaker is a no-op**: `PassTwoEngine#default_circuit_breaker` is `lambda { |&block| block.call }`. The `rescue CircuitBreaker::CircuitBrokenException` clause in `annotate_interpersonal` will never trigger until a real breaker is injected.

3. **TenorTracker mutates in-place**: `calculate_shifts` replaces structs in the `@turns` array rather than returning a new array. Callers passing their only reference will see it mutated.

4. **Keyword search doesn't join tables**: `keyword_search` queries `clauses` alone. Scalar filtering happens in Ruby after the RRF merge (N+1 queries in `apply_filters`). Fine for small sets, needs SQL join at scale.

5. **MarkdownLoader depends on Inkmark + PragmaticTokenizer**: Both are in the Gemfile but not in the gemspec (dev-only). The main script adds them at runtime.

6. **Pass 2 failure is visible on CLI**: After the fix in `pass_two_engine.rb`, DSPy errors now print `[WARN]` to `$stderr` with the clause ID and error message. Before this fix, failures were silent (only in journald).

7. **`duplicate` method in `mean`**: `SpeakerProfiler#mean` and `CorrelationAnalyzer#mean` are identical. Not yet extracted to a shared module.

8. **Hardcoded paths in main script**: `scripts/parse_metacognitive_coprocessor.rb` has `../../../Notebook/NotebookLM/metacognitive-coprocessor/` hardcoded. Use `FILE=...` env var for other files.

9. **Embedding dimension is 1536**: Hardcoded for OpenAI `text-embedding-ada-002`. Change the column type in `create_embeddings_table` if using a different model.

10. **Zeitwerk collapsing**: `pass_one/`, `pass_two/`, `storage/`, `retrieval/`, `analysis/`, `formatters/` directories are collapsed — files in these dirs are loaded at the `SFL::Compiler` namespace level (e.g., `PassOneEngine` not `SFL::Compiler::PassOne::PassOneEngine`).

## Test Structure

- `spec/spec_helper.rb`: Bundler setup, RSpec config (random order, focus filter, verified doubles).
- **Existing specs**: `types_spec.rb` (type constraints), `tenor_tracker_spec.rb` (shift detection), `speaker_profiler_spec.rb`, `correlation_analyzer_spec.rb`, `json_formatter_spec.rb`, `csv_formatter_spec.rb`, `markdown_formatter_spec.rb`.
- **Missing specs** (see `BACKLOG_FIXES.md`): Pipeline integration tests, MarkdownLoader tests, repository tests, PassTwoEngine tests, ThemeRhemeExtractor tests.
- **Test data**: `spec/fixtures/conversations/sample.jsonl` — 5-turn conversation.

## Experiments

The `experiments/` directory contains throwaway scripts validating SFL theories. Results in `experiments/RESULTS.md`: 5/6 theories validated. FCA, ID3, cohesion correlations, and DSPy Theme/Rheme all validated. spaCy-only Theme/Rheme failed (16.7% accuracy). These scripts are intentionally <100 lines, no error handling, no abstraction.

## Claude Code / OpenCode Integration

- **Skill**: `.claude/skills/sfl-analyze/SKILL.md` — composes `sfl-analyze` CLI invocations for conversation/documentation/context analyses.
- **Agent**: `.claude/agents/sfl-analyzer.md` — expert agent for SFL analysis tasks.
- **OpenCode plugin**: `.opencode/plugins/graphify.js` — graph visualization plugin.
