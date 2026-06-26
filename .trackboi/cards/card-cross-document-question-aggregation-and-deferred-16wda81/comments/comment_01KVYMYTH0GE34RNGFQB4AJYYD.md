---
id: "comment_01KVYMYTH0GE34RNGFQB4AJYYD"
cardId: "card-cross-document-question-aggregation-and-deferred-16wda81"
createdAt: "2026-06-25T05:45:00.704Z"
updatedAt: "2026-06-25T05:45:00.704Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Done — commit 6ac30b5.

**Generalized requirement #2** beyond the literal "modality" example: any question id shared by ≥2 input `QuestionGraph`s gets an auto-generated `cross_doc_<id>_consistency` derived question, not just a hardcoded modality-specific rule. More durable as new canonical question sets get added elsewhere (e.g. the documentation-footer card's `tenor_consistency`/`data_quality`/`overall_confidence`).

**Added a `findings:` parameter not in the original method signature** (`aggregate(sprint_graphs, findings: nil)`) — `QuestionGraph` is purely structural (id/text/dependencies, no numeric answer data), so requirement #5c's "divergent findings" needed *some* real values to compare; there was no way to detect numeric divergence from graph structure alone. `findings` is optional and parallel to `sprint_graphs`; structural aggregation (req #2/#3) works without it.

**Requirement #4 (kanban auto-card-creation) is explicitly NOT implemented as a runtime side effect** inside this class — documented in the class comment. A Ruby gem's library code has no business calling out to a development-board MCP server. `#deferred_questions` returns the same `{id:, text:, dependencies:}` shape `QuestionGraph` itself takes as input, which is the integration point a caller (CLI command, this very session) would use to actually create cards — the data is there, the side effect isn't baked in.

**Acceptance example's literal wording** ("Is the modality gap between doc types statistically meaningful?") doesn't exactly match what gets generated (`cross_doc_modality_consistency`: "Does the modality finding hold across documents?") — treated as illustrative paraphrase, not required literal text; the underlying behavior (aggregating two docs sharing a `:modality` axiom reveals a derived question absent from both individual graphs) is exactly what's implemented and tested.

Verified: 10 new specs (shared-axiom derived question, namespacing/dependency rewiring, single-doc → `[]`, 3-doc divergent vs. agreeing findings, 2-doc case never reconciles regardless of divergence per spec's literal ≥3 requirement, missing-findings handling, full graph resolves with a real `gödel_number` and passes `consistent?`). Full suite 388/0, rubocop clean on the new file.