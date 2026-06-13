# SFL Compiler — Prioritized Fix Backlog

Generated from SIFT assessment. Weights: Critical → High → Medium.

---

## Tier 0: Critical (blocking production use)

### 0.1 — Pass 2 Silent Failure

- **File**: `lib/sfl/compiler/pass_two/pass_two_engine.rb`
- **Lines**: 211-224 (`SFLAnnotator#call` rescue block)
- **Problem**: Catches ALL `StandardError` and silently returns defaults (modality=0.5, tenor=0.5, mood=declarative). The LLM annotation is effectively dead — every clause gets the same default. Actual errors are only logged to journald, invisible to CLI users.
- **Fix options** (choose one):
  - **Option A** (quick): Move the `rescue` from `SFLAnnotator#call` up to `PassTwoEngine#annotate`, log to STDOUT using `$stderr.puts` alongside journald, and re-raise `PassTwoError`.
  - **Option B** (better): Add STDOUT logging with colorized error output to `SFL::Compiler.logger` so errors appear in terminal. Keep the default fallback but only use it for non-critical annotation paths.
  - **Option C** (best): Add a `verbose` flag that surfaces DSPy errors to STDOUT, and write a test that verifies the circuit breaker fallback works with a mocked failure.
- **Test required**: New spec at `spec/sfl/compiler/pass_two/pass_two_engine_spec.rb` — mock DSPy to raise, verify defaults returned and error logged.

### 0.2 — No Pipeline Integration Tests

- **Problem**: `Pipeline#compile` (139 lines) is the core orchestration — zero tests.
- **Fix**: Create `spec/sfl/compiler/pipeline_spec.rb` with:
  - Test `compile` with mocked `PassOneEngine` and `PassTwoEngine`
  - Verify `compile_pass_one` returns correct pairs
  - Verify `compile_pass_two` delegates to PassTwoEngine
  - Test store=true/false, embed=true/false paths
  - Test error propagation from both PassOneError and PassTwoError
- **Mocking strategy**: Use RSpec mocks — no real spaCy or DSPy needed.

---

## Tier 1: High (should fix before next release)

### 1.1 — `\\\\n` vs `\n` in MarkdownFormatter

- **File**: `lib/sfl/compiler/formatters/markdown_formatter.rb`
- **Lines**: 58 and 71
- **Problem**: Uses `\\\\n` in heredoc which renders as literal `\n` in output
  - Line 58: `"|---------|-----------|-------|----------|--------------|\\\\n"` → should be `\n`
  - Line 71: Same pattern in correlations_table
- **Fix**: Change `\\\\n` to `\n` on both lines.
- **Test required**: Add `spec/sfl_compiler/formatters/markdown_formatter_spec.rb` — verify rendered output contains actual newlines, not literal `\n`.

### 1.2 — MarkdownLoader Specs

- **File**: `lib/sfl/compiler/markdown_loader.rb` (222 lines)
- **Problem**: Complex chunking logic (YAML frontmatter, Inkmark sections, HTML code block removal, entity decoding, PragmaticTokenizer normalization) — zero test coverage.
- **Test file**: Create `spec/sfl/compiler/markdown_loader_spec.rb`
- **Test cases**:
  - Strips YAML frontmatter
  - Splits by ATX headings
  - Drops fenced code blocks
  - Decodes HTML entities (`&amp;` → `&`)
  - Extracts preamble before first heading
  - Respects `min_length` and `skip_empty`
  - Generates correct `document_id` format (`file#section-slug`)
  - Handles empty/null text
  - `self.load` convenience method

### 1.3 — TenorTracker Mutation Side-Effect

- **File**: `lib/sfl/compiler/analysis/tenor_tracker.rb`
- **Line**: 21
- **Problem**: `calculate_shifts` replaces structs in the `@turns` array in-place rather than returning a new array. Callers relying on immutability of the originally passed array get their data mutated.
- **Fix**: Either:
  - Document clearly with `@note` that this method mutates the input array
  - Or change to return a new array: `turns.each_with_index.map { |t, i| ... }`
- **Test**: Update `tenor_tracker_spec.rb` to verify original array preservation if option 2 is chosen.

### 1.4 — Storage/Repository Specs

- **Files**: `lib/sfl/compiler/storage/clause_repository.rb`, `embedding_repository.rb`
- **Problem**: All CRUD operations, filtering, and nearest-neighbor search are untested.
- **Test files**:
  - `spec/sfl/compiler/storage/clause_repository_spec.rb` — test `store`, `find`, `find_by_interpersonal`, `find_by_process_type`
  - `spec/sfl/compiler/storage/embedding_repository_spec.rb` — test `store`, `nearest_neighbors`
- **Strategy**: Use a test database (Sequel SQLite in-memory) or mock Sequel.

---

## Tier 2: Medium (technical debt)

### 2.1 — Duplicate `mean` Method

- **Files**: `lib/sfl/compiler/analysis/speaker_profiler.rb` (line 63), `correlation_analyzer.rb` (line 33)
- **Problem**: `mean` defined identically in two classes.
- **Fix**: Extract to `SFL::Compiler::Analysis::Statistics` module or a shared concern.

### 2.2 — Hardcoded Script Paths

- **File**: `scripts/parse_metacognitive_coprocessor.rb`
- **Lines**: 31-38
- **Problem**: Hardcoded paths to `../../../Notebook/NotebookLM/...` break outside the original dev setup.
- **Fix**: Make configurable via ENV variables with sensible defaults:
  - `NOTEBOOK_SOURCES_DIR` (default: the hardcoded path)
  - `NOTEBOOK_REPORTS_DIR` (default: the hardcoded path)
  - Fall back with a warning if the default doesn't exist.

### 2.3 — Missing Formatter Specs (CSV + Markdown)

- **Files**: `lib/sfl/compiler/formatters/csv_formatter.rb`, `markdown_formatter.rb`
- **Problem**: Only JSONFormatter has tests.
- **Fix**: Add `csv_formatter_spec.rb` (verify headers, row format, truncation) and `markdown_formatter_spec.rb` (verify table rendering, insight formatting, tenor labels).

### 2.4 — ThemeRhemeExtractor Specs

- **File**: `lib/sfl/compiler/llm_tools/theme_rheme_extractor.rb`
- **Problem**: LLM integration with JSON parsing + fallback logic — no tests.
- **Fix**: Add `spec/sfl/compiler/llm_tools/theme_rheme_extractor_spec.rb` — test `parse_theme_rheme_response` with valid JSON, invalid JSON, missing fields, and LLM failure fallback.

### 2.5 — Code Climate / Linting

- **Run**: `bundle exec rubocop` and fix any offenses (there are likely frozen_string_literal ordering issues, line length violations, etc.)
- **Add to CI**: `.github/workflows/lint.yml`

---

## Execution Plan

### Phase 1 — Fix the critical bug
```bash
# Fix Pass 2 silent failure (0.1) + add test
```

### Phase 2 — Boost test coverage
```bash
# Pipeline (0.2) + MarkdownLoader (1.2) + Repos (1.4) formatters (1.1, 2.3)
# Target: >60% line coverage
```

### Phase 3 — Clean up technical debt
```bash
# Duplicate methods (2.1) + hardcoded paths (2.2) + RuboCop (2.5)
```

### Phase 4 — ThemeRhemeExtractor tests
```bash
# If this component is still in use (2.4)
```
### Analyzer helper duplication (flagged in Task 6 code review, 2026-06-12)

`mean` now has 4 copies (SpeakerProfiler, CorrelationAnalyzer,
ConversationAnalyzer, DocumentationAnalyzer); `report_progress`,
`timeline`/`tenor_timeline`, and `field_evolution` are duplicated between the
two analyzers. Extract a shared `Analysis::Aggregations` mixin before adding
any further analyzer.

### sfl-analyze CLI follow-ups (final review, 2026-06-12)

- `CLI.parse` rejects inputs starting with `--`; a context query beginning
  with a dash would be misread. Consider `--` separator support.
- CSV/JSON formatters do not honor `unit_label`/`actor_label` (markdown
  only); documentation reports' CSV/JSON still say turn/speaker.

## PyCall/Python process isolation (hardening)

`Pipeline#compile` now forces `GC.start` at the Pass 1 → Pass 2 boundary so
dead spaCy/PyCall wrappers are swept on the main (GIL-capable) thread
(b47e27c, gdb-verified GVL/GIL deadlock otherwise). This guards the known
window, but conservative stack scanning can in principle keep a wrapper
alive past the boundary sweep and free it on a worker later. The structural
fix is process isolation: run spaCy in a subprocess (JSON over pipe) so no
Python object ever shares a process with the threaded Pass 2. Do this if
the hang ever reappears despite the boundary sweep.
