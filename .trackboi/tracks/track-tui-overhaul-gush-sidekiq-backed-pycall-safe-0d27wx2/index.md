---
id: "track-tui-overhaul-gush-sidekiq-backed-pycall-safe-0d27wx2"
title: "TUI overhaul (Gush/Sidekiq-backed, PyCall-safe)"
slug: "tui-overhaul-gush-sidekiq-backed-pycall-safe"
createdAt: "2026-06-25T00:39:36.970Z"
updatedAt: "2026-07-03T04:45:06.266Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**COMPLETE — all 5 cards shipped, including end-to-end verification.** The `--live` split-pane TUI now runs on the Gush/Sidekiq workflow: `WorkflowPoller` reads Redis state from Bubbletea's main thread (PyCall-free), analysis runs in separate Sidekiq worker processes, and `--live` is wired for both `conversation` and `documentation` subcommands. "Verify --live end-to-end: no segfault, real Sidekiq worker, real progress render" passed. The old in-process `BatchApp#run_analysis` segfault path is replaced. Residual scope (multi-file `--live`) deliberately deferred — open a new card if needed. No further work in this track (verified 2026-07-03).