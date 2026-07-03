---
id: "card-vision-workflow-editor-select-clauses-generate-t-1bvxolk"
boardId: "default"
title: "[Vision] Workflow editor: select clauses, generate text"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "backlog"
rank: "yyv"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T11:58:27.439Z"
updatedAt: "2026-07-03T11:58:27.439Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Future direction mentioned by the user during the "Adapt ReviewView" card (2026-07-03), explicitly described as a longer-term idea, not something to build now: a visual workflow editor where a user selects multiple clauses (across documents/conversations) and composes/generates new text from them.

Not scoped. No relationship yet to the review queue, Safe RAG Hypothesis Validator, or any existing Falcon endpoint — closest existing building block is probably `POST /synthesize` (retrieval-grounded LLM answer with citations), but a workflow *editor* implies a persistent, user-authored graph/pipeline of steps, which is a different shape of feature entirely (closer to the GEB sprint-role workflow machinery than to a single synthesis call).

Purely a placeholder so this idea isn't lost — needs real scoping (brainstorming session) before any implementation work starts.