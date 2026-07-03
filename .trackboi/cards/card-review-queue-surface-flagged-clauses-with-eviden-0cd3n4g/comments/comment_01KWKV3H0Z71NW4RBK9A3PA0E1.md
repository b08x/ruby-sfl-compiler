---
id: "comment_01KWKV3H0Z71NW4RBK9A3PA0E1"
cardId: "card-review-queue-surface-flagged-clauses-with-eviden-0cd3n4g"
createdAt: "2026-07-03T11:16:29.343Z"
updatedAt: "2026-07-03T11:16:29.343Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done.** Surface decision was already resolved via the track's own references (Falcon API endpoints consumed by both TUI and React, not a separate TUI-only pane) — this card builds those endpoints. TUI `EvidencePane` evolution and React's "Adapt ReviewView" card remain separately scoped.

**Schema gap found and fixed**: `reasoning_trace` (premises/inference_rule/confidence/derivation_hash) was never persisted to `interpersonal_payloads` — only the plain `reasoning` string was. A DB-backed review queue had nothing to show for "evidence" beyond mood/tenor/modality without it. Added a nullable `reasoning_trace` jsonb column (same backfill pattern as `source_type`/`annotation_source`); `ClauseRepository#store`/`#update_interpersonal` now persist it.

- `ClauseRepository#review_queue`: clauses whose `annotation_source` isn't in `TRUSTED_ANNOTATION_SOURCES` (same predicate `TUI::EvidencePane` already uses), paginated, with reasoning + reasoning_trace evidence `GET /clauses` doesn't return. Verified live against real Postgres before writing.
- `GET /clauses/review-queue` — same `{clauses:, total:, limit:, offset:}` shape as `GET /clauses`.
- `POST /clauses/:id/review` — `{decision: accepted|rejected|re_annotated, reviewer?, notes?}`. accepted/rejected record synchronously (200). re_annotated dispatches `ReannotateClauseWorkflow` (202, job+poll — same shape as `POST /pipeline/compile`'s async path). 404/400 handled.

**Honest scope gap, not silently omitted**: "fuzzy-match provenance" (Jaro-Winkler near-misses) is only ever logged to stderr/journald by `PassTwoEngine#log_classification_gap` today, never attached to the stored payload — nothing in the DB to surface yet. Documented in the repository method's comment rather than faked. Wiring that through is a `PassTwoEngine` change, out of this card's boundary.

Verified: 770 examples / 0 failures (seeds 1, 2, 42). Rubocop: net improvement on `clause_repository.rb`. Committed as `3d4138c`.

Noted one pre-existing, unrelated flake in `server_spec.rb` (`NameError: uninitialized constant Gush` when that file runs in total isolation — missing top-level `require "gush"`) — reproduces identically on the pre-this-commit baseline, passes in full-suite context. Not fixed here; flagging for a future cleanup card rather than scope-creeping into it.