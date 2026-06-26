---
id: "card-build-a-pycall-free-gush-redis-status-poller-for-0ouwdfv"
boardId: "default"
title: "Build a PyCall-free Gush/Redis status poller for the TUI"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-tui-overhaul-gush-sidekiq-backed-pycall-safe-0d27wx2"
column: "todo"
rank: "yj7"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T00:40:10.607Z"
updatedAt: "2026-06-25T01:51:41.392Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Core piece of the rebuild. A small class (e.g. `TUI::WorkflowPoller`) that wraps `Gush::Workflow.find(id)` / `flow.jobs` and exposes plain progress data (per-turn status, counts, final output) to a Bubbletea model on a `Bubbletea.tick`. Must never touch `PassOneEngine`/`Pipeline`/spaCy/PyCall directly — it only talks to Redis (via Gush) and, once the reduce job finishes, the stored AnalysisResult. This is what replaces `BatchApp`'s `Queue` + background-`Thread.new`-running-Pass-1 design (see the track's known-issues reference). Reference proc-tui's `ProcessManager` (`.claude/skills/sfl-tui/references/proc-tui-patterns.md`) for the "poll an external thing, never run it in-thread" shape.