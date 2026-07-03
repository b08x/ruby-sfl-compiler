---
id: "card-wire-dashboardview-sidebar-stats-to-falcon-workf-117ddrf"
boardId: "default"
title: "Wire DashboardView + Sidebar stats to Falcon /workflows and analysis-report endpoints"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:41:53.664Z"
updatedAt: "2026-07-03T13:17:24.844Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Depends on the GraphContext/Falcon wiring card. Two pieces: (1) `DashboardView.tsx` renders tenor timeline (line chart), speaker profiles table, correlation heatmap from a saved analysis result — consumes a new `GET /analyses/:id` endpoint. (2) `Sidebar.tsx`'s session-stats panel (currently hardcoded "Rated 0" / "Skills 0" placeholders) and a new Workflow Monitor view poll `GET /workflows/:id/status` every 2s for live Gush/Sidekiq job progress (CompileTurnJob per turn: queued/running/done) — same data `TUI::WorkflowPoller` already reads, just consumed over HTTP instead of Redis directly. Acceptance: Dashboard renders a real tenor timeline from a stored analysis; Sidebar/Monitor show job progress updating in real time during a live `--live` run.