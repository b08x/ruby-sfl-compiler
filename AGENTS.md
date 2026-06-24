# AGENTS.md — OpenCode Session Guide

## Commands

```bash
# Tests (unit-only, no DB/LLM needed)
bundle exec rspec spec/ --format documentation
bundle exec rspec spec/sfl/compiler/types_spec.rb  # single file

# If bundle exec rspec fails (Gemfile doesn't use gemspec, load path issue)
bin/rspec spec/

# Lint
bundle exec rubocop

# CLI
bundle exec sfl-analyze conversation chat.jsonl --output-dir ./output/latest
bundle exec sfl-analyze documentation docs/ --store
bundle exec sfl-analyze context "query" --min-modality 0.7 --limit 5

# Database reset (drops + recreates all 4 tables)
bundle exec rake db:refresh
bundle exec rake db:dump
```

## Critical Gotchas

1. **Zeitwerk manifest files**: `analysis/` and `formatters/` use NESTED modules (`Analysis::TenorTracker`, `Formatters::CSVFormatter`). New files in these dirs MUST be added to `lib/sfl/compiler/analysis.rb` or `lib/sfl/compiler/formatters.rb` or you get `uninitialized constant`. Other dirs (`pass_one/`, `pass_two/`, `storage/`, `retrieval/`) use FLAT constants and load automatically.

2. **GC + PyCall deadlock**: Pass 1 (spaCy via PyCall) + Pass 2 (Ruby LLM) can deadlock GC. The pipeline calls `GC.start` between passes. Don't remove this.

3. **Integration tests are broken**: `spec/integration/` misuses RSpec API (`integration_env_ready?` called from inside examples). Exclude: `--exclude-pattern "integration/**/*"`

4. **`bundle exec` load path**: Gemfile uses `gemspec`, but `exe/sfl-analyze` unshifts `lib/` itself. If `bundle exec rspec` fails, try `bin/rspec`.

5. **TenorTracker mutates in-place**: `calculate_shifts` replaces structs in the `@turns` array rather than returning new objects.

6. **`annotation_source` matters**: Check it before interpreting values. `"fallback"` = placeholder (0.5), not measurement. Reports surface this in a Data Quality section.

7. **Embedding dimension is 768**: Uses Ollama `embeddinggemma:latest`. Change `create_embeddings_table` column type if using a different model.

8. **Keyword search ANDs all terms**: `plainto_tsquery('simple', ...)` requires every word to match. Full questions often miss; use key terms instead.

## Architecture

See `CLAUDE.md` for full architecture. Quick reference:

- **Entry**: `exe/sfl-analyze` → `lib/sfl/compiler/cli.rb` → `Bootstrap.call` → Pipeline
- **Pass 1**: `PassOneEngine` (spaCy) → `IdeationalExtractor` (rule-based)
- **Pass 2**: `PassTwoEngine` (DSPy.rb LLM, batched ~12 clauses/call)
- **Storage**: `clauses`, `ideational_payloads`, `interpersonal_payloads`, `embeddings` (PostgreSQL + pgvector)
- **Retrieval**: `HybridRetriever` (RRF: semantic + keyword, scalar filters)

## Conventions

- Bootstrap is the ONLY ENV reader — analyzers are UI-agnostic (no puts/exit/ENV)
- All data types in `lib/sfl/compiler/types.rb` (Dry::Struct with constrained enums)
- Custom errors inherit from `SFL::Compiler::Error`
- Frozen string literals everywhere
- RuboCop with Shopify + RSpec plugins, 2-space indent, double quotes
