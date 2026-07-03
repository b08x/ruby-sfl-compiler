---
id: "card-implement-analysis-dashboard-and-workflow-monito-0fmij80"
boardId: "default"
title: "Implement Analysis Dashboard and Workflow Monitor views"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:14:40.340Z"
updatedAt: "2026-07-03T05:41:28.531Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Two secondary views: (1) **Analysis Dashboard** — tenor timeline (line chart via Recharts), speaker profiles table, correlation heatmap (process_type × avg tenor/modality). Consumes analysis result JSON from `GET /analyses/:id` (new endpoint). (2) **Workflow Monitor** — live Gush/Sidekiq workflow status for running `ConversationAnalysisWorkflow` or `SprintWorkflow` jobs. Polls `GET /workflows/:id/status` every 2s, renders job-level progress (CompileTurnJob per turn: queued/running/done). Acceptance: Dashboard renders tenor timeline from a saved analysis result; Monitor shows job progress updating in real time.