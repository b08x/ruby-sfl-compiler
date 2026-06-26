---
id: "card-verify-live-end-to-end-no-segfault-real-sidekiq--02r8abg"
boardId: "default"
title: "Verify --live end-to-end: no segfault, real Sidekiq worker, real progress render"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-tui-overhaul-gush-sidekiq-backed-pycall-safe-0d27wx2"
column: "todo"
rank: "yr"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T00:40:17.647Z"
updatedAt: "2026-06-25T01:51:34.679Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Depends on: the BatchApp rewrite card. Manual + scripted verification that `bundle exec sfl-analyze conversation <file> --live` (with `bundle exec sidekiq -q gush` running in another terminal and Redis up) runs an actual multi-turn conversation to completion without the `[BUG] Segmentation fault` previously seen in `pycall/pyobject_wrapper.rb`. Confirm the TUI's progress view updates as turns complete and the final result renders. This closes out the root issue this whole track exists to fix.