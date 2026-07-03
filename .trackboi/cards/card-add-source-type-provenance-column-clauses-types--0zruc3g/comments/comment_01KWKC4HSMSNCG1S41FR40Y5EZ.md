---
id: "comment_01KWKC4HSMSNCG1S41FR40Y5EZ"
cardId: "card-add-source-type-provenance-column-clauses-types--0zruc3g"
createdAt: "2026-07-03T06:54:54.260Z"
updatedAt: "2026-07-03T06:54:54.260Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Complete, verified end-to-end live against a real Postgres DB + running Falcon server (not just mocks).**

**Chain built**: migration (`source_type` on `clauses`, `String not null default "unspecified"`, via the existing `backfill_columns`/`ColumnBackfill` pattern — added an index too, which required swapping `create_indices`/`backfill_columns` order in `Migrator#run_all` since the index referenced a column that didn't exist yet under the old order) → `ClauseRepository#store(annotated, topic:, source_type:)` (mirrors the existing `topic:` precedent — deliberately *not* added to `Types::AnnotatedClause` itself, since it's storage-time provenance, not an annotation) → `Pipeline#compile(..., source_type: nil)` → `HybridRetriever#apply_filters` (new `source_type_map` lookup against `clauses`, same pattern as the existing `interpersonal_map`/`ideational_map`) → Falcon `/retrieve`'s `validate_filters` whitelist.

**Call sites tagged**: `CompileTurnJob`/`ConversationAnalyzer#compile_clauses` → `chat_native`; `CompileSectionJob` → `doc_markdown`; `KnowledgeBaseAnalyzer` → `vault_markdown`/`vault_pdf`/`vault_image` (derived from the loader's extension, added `source_type_for(ext)`); `/pipeline/compile`'s sync path → `api`.

**Refactor along the way**: `compile_artifact`'s parameter list hit rubocop's `Metrics/ParameterLists` (6/5) once `source_type` was added as a 6th positional arg — bundled `source_file`/`mtime`/`source_type` into a single `file_meta:` hash instead (all three come from the same loader tuple anyway, so this is a real cohesion improvement, not just offense-suppression).

**Live verification** (not just specs): ran the migration against the real dev DB, confirmed the column + default via `db.schema`; compiled and stored a real clause through the full Pass 1+2 pipeline tagged `vault_markdown`; confirmed `HybridRetriever#retrieve` finds it when filtering `source_type: vault_markdown` and correctly excludes it when filtering `source_type: chat_native`; repeated the same check over the actual running Falcon `/retrieve` HTTP endpoint — both filters behaved correctly (1 result / 0 results).

**Tests**: 6 new specs (`HybridRetriever` ×2, `ClauseRepository#store` ×2, Falcon `/retrieve` ×1) plus 5 pre-existing exact-kwarg specs updated for the new `source_type:` argument. Full suite 705/705 (clean seed).

**Found and flagged, not fixed (out of scope)**: a genuine pre-existing bug in `lib/sfl/compiler/pass_two/provider_fallback.rb` — references `Bootstrap::BootstrapError`, but the real constant is `SFL::Compiler::BootstrapError`. Causes intermittent `NameError` in `circuit_breaker_spec.rb` depending on RSpec's random seed/test order (constant-resolution timing, not something my changes touched or caused — confirmed by reproducing it against the pre-this-card commit with the same seed). Worth its own card.