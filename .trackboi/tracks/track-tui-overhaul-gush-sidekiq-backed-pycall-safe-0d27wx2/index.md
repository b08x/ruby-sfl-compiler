---
id: "track-tui-overhaul-gush-sidekiq-backed-pycall-safe-0d27wx2"
title: "TUI overhaul (Gush/Sidekiq-backed, PyCall-safe)"
slug: "tui-overhaul-gush-sidekiq-backed-pycall-safe"
createdAt: "2026-06-25T00:39:36.970Z"
updatedAt: "2026-06-25T00:39:51.279Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Rebuild the `sfl-analyze tui` live-progress experience on top of the new Gush/Sidekiq job workflow (see `docs/superpowers/plans/2026-06-24-gush-conversation-workflow.md` and `.claude/skills/sfl-tui/`), replacing the broken in-process Bubbletea `--live` view (`lib/sfl/compiler/tui/batch_app.rb`) that segfaults because PyCall/spaCy isn't thread-safe.