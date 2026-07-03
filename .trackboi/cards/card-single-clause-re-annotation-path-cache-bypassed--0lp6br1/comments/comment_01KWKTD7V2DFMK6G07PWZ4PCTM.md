---
id: "comment_01KWKTD7V2DFMK6G07PWZ4PCTM"
cardId: "card-single-clause-re-annotation-path-cache-bypassed--0lp6br1"
createdAt: "2026-07-03T11:04:19.042Z"
updatedAt: "2026-07-03T11:04:19.042Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done.**

- `ClauseRepository#find_pass_one_output`: reconstructs typed `Types::SyntacticClause`/`Types::IdeationalPayload` from the `clauses`/`ideational_payloads` tables so `PassTwoEngine#annotate` can be re-run without a fresh spaCy pass. Verified live against real Postgres before writing: jsonb payloads round-trip with **string** keys (not the symbol keys `#store`'s callers use), and `Sequel::Postgres::JSONBArray`/`JSONBHash` fail Dry::Types' strict `Array`/`Hash` checks unconverted. `clauses` has no `root_index` column (only a `root_token` snapshot) — recomputed the same way `PassOneEngine` originally derived it (first token with `dep == "ROOT"`).
- `ClauseRepository#update_interpersonal`: targeted UPDATE on the existing `interpersonal_payloads` row (repo previously only had insert/find/delete).
- `ReannotateClauseJob` (Gush::Job) + `ReannotateClauseWorkflow` (trivial single-job wrapper, since Gush has no bare "enqueue one job" API): reconstructs Pass 1 output → `PassTwoEngine#annotate` directly (never `Pipeline#compile`, so `PipelineCache` — only ever consulted inside `Pipeline#compile`'s resume path — is bypassed by construction, not a flag) → `update_interpersonal` → `record_review(decision: "re_annotated")` snapshotting the pre-recompile `annotation_source`.
- Per the card's explicit note: `annotation_source` on the result stays whatever `PassTwoEngine` itself sets (llm/fallback) — not forced to `"human"`, since the values are still machine-produced even though a human triggered the recompile.
- Runs as its own Sidekiq worker process, consistent with every other pipeline stage's job+poll model.

Verified: 759 examples / 0 failures. The workflow spec runs the job to completion through **real Gush/Redis** (same pattern as `SprintWorkflow`/`ConversationAnalysisWorkflow` specs), not a mocked DAG. Rubocop clean. Committed as `32b42d6`.

Out of scope (separate backlog card): the queue UI that actually dispatches `ReannotateClauseWorkflow` from a human's "re-annotate" click.