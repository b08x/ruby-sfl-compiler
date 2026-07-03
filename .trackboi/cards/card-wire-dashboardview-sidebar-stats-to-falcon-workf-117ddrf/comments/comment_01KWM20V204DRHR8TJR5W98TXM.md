---
id: "comment_01KWM20V204DRHR8TJR5W98TXM"
cardId: "card-wire-dashboardview-sidebar-stats-to-falcon-workf-117ddrf"
createdAt: "2026-07-03T13:17:21.344Z"
updatedAt: "2026-07-03T13:17:21.344Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done.** Scoped down from the full `/analyses/:id` idea — `GET /workflows/:id/status`'s existing `output` field (from `ReduceTurnsJob#full_output`) already carries everything the Dashboard needs once a `ConversationAnalysisWorkflow` finishes, so no new backend endpoint was needed.

**New:** `src/contexts/WorkflowContext.tsx` — dispatches `POST /workflows` and polls status every 2s, tracking the active `workflow_id` in localStorage. Single source of truth for both Dashboard and Sidebar (avoids double-polling).

**DashboardView.tsx**: "Run Analysis" card (jsonl_path input + live compile progress), and once finished: stat cards, a hand-rolled SVG tenor timeline (no charting dep in this app), speaker profiles table, process×tenor correlation heatmap, insights list.

**Sidebar.tsx**: session-stats panel replaced with a live "Workflow Monitor" (status + turns compiled), both expanded and as the collapsed progress bar.

**Real bug found and fixed via live testing** (sfl-compiler `56b848a`): `GET /workflows/:id/status` crashed with `NoMethodError: undefined method 'iso8601' for an instance of Integer` on every poll. `Gush::Job#started_at`/`#finished_at` are Unix integers (`Time.now.to_i`), not `Time` objects — the existing spec mocked them as `Time` doubles that happened to respond to `#iso8601`, masking the bug. Fixed with a `unix_iso8601` helper; specs updated to use real integers.

Verified end-to-end in Chrome against real Falcon + Sidekiq + Redis: dispatched against `sample.jsonl`, watched 0/6 → 6/6 turns compile, confirmed Dashboard's chart/tables and Sidebar's monitor both render the real output. 770 sfl-compiler examples green, ConvoWorkbench `tsc --noEmit` clean.

Commits: sfl-compiler `56b848a`, ConvoWorkbench `838cc12`.