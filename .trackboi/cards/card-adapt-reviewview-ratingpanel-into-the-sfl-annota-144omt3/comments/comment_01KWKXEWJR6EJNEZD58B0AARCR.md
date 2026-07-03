---
id: "comment_01KWKXEWJR6EJNEZD58B0AARCR"
cardId: "card-adapt-reviewview-ratingpanel-into-the-sfl-annota-144omt3"
createdAt: "2026-07-03T11:57:38.776Z"
updatedAt: "2026-07-03T11:57:38.776Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done.** Kept ReviewView's list/detail/decision-panel layout (it was structurally right) but rebuilt every pane as a thin client of the review-queue Falcon endpoints instead of GraphContext conversation state, replacing the correctness/tone/format/style_tags rubric with the three decisions `Types::ReviewDecision` actually supports.

- `ReviewQueueList` (was `ConversationList`): paginated `GET /clauses/review-queue`.
- `ClauseEvidenceViewer` (was `ConversationViewer`): reasoning text + reasoning_trace (premises, inference rule, confidence). No by-id lookup endpoint exists, so it re-fetches a page and finds the clause — documented tradeoff, not an oversight.
- `DecisionPanel` (was `RatingPanel`): accept/reject/re-annotate. Re-annotate dispatches `ReannotateClauseWorkflow`, polls `GET /workflows/:id/status`, and shows real job status + live elapsed time instead of a static spinner, with a poll-failure banner + Retry button (resumes the same workflow rather than re-dispatching — the job keeps running server-side even if the browser's connection drops).

Deleted the three replaced components outright (git-recoverable, nothing else imported them). `types/sfl.ts`'s `AnnotationSource` was missing `human`/`chunk_artifact` entirely — widened to match the server enum; `GraphExplorer.tsx` needed the same fix to stay exhaustive (tsc caught it immediately).

**Found a real backend bug via live browser testing, not unit tests**: Accept never actually cleared a clause from the queue — `ClauseRepository#review_queue` only excluded by `annotation_source`, and Accept deliberately doesn't touch it. Fixed server-side (`sfl-compiler` commit `ca1e0a7`) and re-verified in the browser. `ClauseRepository`'s own spec used mocked scopes and would never have caught this — this is exactly the "verify live, not just mocks" discipline paying off again this session.

Verified end-to-end via Chrome automation against the real Falcon API + Postgres + a real Sidekiq worker: seeded clauses, clicked through all three decisions, watched the elapsed timer tick against a genuinely running job, killed the API mid-poll to confirm the retry path, confirmed recovery. `tsc --noEmit` clean. Committed as ConvoWorkbench `d3d6606` + sfl-compiler `ca1e0a7`.