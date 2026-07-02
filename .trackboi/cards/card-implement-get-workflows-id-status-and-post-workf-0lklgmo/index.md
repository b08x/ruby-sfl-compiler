---
id: "card-implement-get-workflows-id-status-and-post-workf-0lklgmo"
boardId: "default"
title: "Implement GET /workflows/:id/status and POST /workflows (Gush workflow management)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-falcon-async-http-api-1vlq3hz"
column: "done"
rank: "yyU"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:14:26.921Z"
updatedAt: "2026-07-02T19:09:10.803Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
`POST /workflows`: `{jsonl_path}` → creates and starts `ConversationAnalysisWorkflow`, returns `{workflow_id, status: "running"}`. `GET /workflows/:id/status`: wraps `Gush::Workflow.find(id)` — returns `{status, jobs: [{name, status, started_at, finished_at}], output: {...}}` (output only present when status is "finished"). Requires Redis. Acceptance: end-to-end — POST a workflow, poll GET until finished, confirm output matches `ConversationAnalyzer#analyze` result shape.