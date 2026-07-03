---
id: "card-bulk-re-annotate-multi-select-clauses-in-the-rev-1aq4dfb"
boardId: "default"
title: "Bulk re-annotate: multi-select clauses in the review queue with per-clause progress"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-human-in-the-loop-annotation-review-0fn8s9p"
column: "backlog"
rank: "yyr"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T11:58:15.783Z"
updatedAt: "2026-07-03T11:58:15.783Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Filed from user feedback during the "Adapt ReviewView" card (2026-07-03): single-clause re-annotate now shows real job status + elapsed time (DecisionPanel), but there's no way to re-annotate multiple flagged clauses at once with visibility into which one is currently being recompiled.

Scope, if picked up:
- **Backend**: a `BulkReannotateClauseWorkflow` (Gush::Workflow) fanning out one `ReannotateClauseJob` per selected clause_id, no dependencies between them (same pattern as `ConversationAnalysisWorkflow`'s per-turn fan-out). `GET /workflows/:id/status` already returns a per-job `jobs[]` array (name/status/started_at/finished_at) — check whether `ReannotateClauseJob`'s Gush job `name` can be made to carry the clause_id/text so the existing status endpoint gives "which clause" for free, or whether a new field is needed.
- **API**: new endpoint (e.g. `POST /clauses/bulk-review`) accepting `{clause_ids: [...], decision: "re_annotated", reviewer?, notes?}` → dispatches the bulk workflow, 202 `{workflow_id, status}`. Scope to re-annotate only (bulk accept/reject as a separate decision, not assumed in scope here).
- **Frontend**: multi-select checkboxes in `ReviewQueueList` + a bulk action bar, and a progress list (not just one spinner) showing each selected clause's individual status as the fan-out completes.

Not started. No design decisions made yet beyond the rough shape above — treat this as a brief, not a spec.