---
id: "comment_01KVYRA06827AZ74DX19JKR29J"
cardId: "card-add-annotation-source-awareness-to-contextsynthe-11jhe4m"
createdAt: "2026-06-25T06:43:32.680Z"
updatedAt: "2026-06-25T06:43:32.680Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done. Implementation deviates from the card's literal text in one notable way — documented below.**

**Pre-implementation discovery (not in the original card):** `annotation_source` was never persisted at all. `interpersonal_payloads` had no such column, and `ClauseRepository#store` never wrote it — `Types::InterpersonalPayload#annotation_source` existed only in memory. Requirement #1's filtering was structurally impossible until this was fixed first. Added:
- `Migrator#backfill_columns` (delegates to new `ColumnBackfill` class) — adds `annotation_source` (default `"llm"`) to `interpersonal_payloads` for already-migrated DBs; fresh installs get it directly in `create_interpersonal_table`.
- `ClauseRepository#store` now writes `annotation_source: annotated.interpersonal.annotation_source`.

**Requirements 1–3 (`lib/sfl/compiler/retrieval/context_synthesizer.rb`):**
- `synthesize(..., include_fallback: false)` partitions retrieved+enriched rows into `citable` vs excluded via `llm_sourced?` (treats nil/missing `annotation_source` — pre-migration rows — as `"llm"`, not excluded).
- Evidence is built and numbered **only from `citable`**, so citation numbers structurally cannot resolve to an excluded clause id — this satisfies requirement #3 by construction, not by trusting the LLM to behave. Verified live: a synthesizer stub returning a citation number that *would* point at an excluded row could not produce that id (see spec "never cites a fallback clause id...").
- Data Quality preamble: `"_Data Quality: N/M retrieved clauses excluded due to fallback annotation._"`, prepended to the answer when N>0. **Deviation:** the card's acceptance text says `"N/M clauses excluded due to fallback annotation"` (no "retrieved") — implemented wording includes "retrieved" for clarity; substance matches.
- When ALL retrieved clauses are excluded, short-circuits without calling the synthesizer (mirrors the existing empty-retrieval short-circuit) — answer is just the preamble.
- `clauses:` in `SynthesisResult` always reports the full retrieved set, fallback included — only LLM-visibility/citability is restricted.

**Requirement 4 (RSpec):** Added 4 new examples to `spec/sfl/compiler/context_synthesizer_spec.rb` covering exactly (a)/(b)/(c) plus the all-excluded short-circuit. Full suite: 410 examples, 0 failures.

**Live verification (real Postgres dev DB + real LLM, not mocked):**
1. Ran `Migrator.new(db).run_all` against the dev DB directly — confirmed `Bootstrap.call(require_db: true)` already runs migrations on every boot, so the column already existed from an earlier connect in this session; verified the backfill path is idempotent and the existing 4,840 rows all read back `annotation_source: "llm"`.
2. Temporarily flipped one real, already-stored clause's `annotation_source` to `"fallback"` in the dev DB, then ran `ContextSynthesizer#synthesize` end-to-end against the real retriever/DB/LLM:
   - Default: query that retrieves only that clause → `answer: "_Data Quality: 1/1 retrieved clauses excluded due to fallback annotation._"`, `cited_clause_ids: []`, synthesizer never called (short-circuit).
   - `include_fallback: true`: same query → real LLM answer grounded in that clause's text, `cited_clause_ids` includes it.
3. Reverted the test clause's `annotation_source` back to `"llm"` afterward — dev corpus left clean.

**Rubocop:** Diffed against true in-place baseline (not a `/tmp` copy — that approach silently used default cop config instead of this repo's `.rubocop.yml`, which cost some wasted cycles before I caught it). Net new debt: zero. Had to refactor twice — extracted a `synthesize_from_citable`/`degraded_result` split in `ContextSynthesizer` (new method's `Metrics/MethodLength` was over) and extracted column-backfill logic into a standalone `ColumnBackfill` class in `database.rb` (the inline version pushed `Migrator`'s `Metrics/ClassLength` over 100 with zero headroom otherwise). Remaining offenses are all pre-existing or marginal +1 growth on already-broken pre-existing methods (e.g. `ClauseRepository#store`'s `AbcSize`), consistent with this session's established precedent for unavoidable single-line necessary additions.

**Residual risk:** `HybridRetriever` itself still has no `annotation_source` awareness in its SQL — filtering happens entirely in `ContextSynthesizer` after enrichment, per the card's own framing ("ContextSynthesizer already independently enriches every row via `@clause_repo.find`"). This is fine at current corpus scale; flagged in case a future SQL-level filter (e.g. "only retrieve llm-sourced clauses") is ever wanted at the retriever layer instead.