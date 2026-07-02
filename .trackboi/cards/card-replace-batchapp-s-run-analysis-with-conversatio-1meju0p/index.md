---
id: "card-replace-batchapp-s-run-analysis-with-conversatio-1meju0p"
boardId: "default"
title: "Replace BatchApp's run_analysis with ConversationAnalysisWorkflow.create/start!"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-tui-overhaul-gush-sidekiq-backed-pycall-safe-0d27wx2"
column: "done"
rank: "yk"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T00:40:14.684Z"
updatedAt: "2026-06-26T14:08:13.574Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Depends on: the status poller card and the ReduceTurnsJob output card. Rewrite `lib/sfl/compiler/tui/batch_app.rb`'s `init`/`run_analysis` to create and start a `SFL::Compiler::ConversationAnalysisWorkflow` instead of running `ConversationAnalyzer#analyze` inline inside a `Bubbletea.batch` `Proc` command (the segfaulting path). The model's `update` drains workflow status from the new poller on each `PollMessage` tick instead of draining an in-process `Queue` fed by `on_progress`/`on_turn_start` callbacks. Requires a Sidekiq worker process to actually be running (`bundle exec sidekiq -q gush`) for jobs to execute — document this as a prerequisite in the TUI's startup/help text, similar to how Postgres/spaCy are already documented prerequisites in CLAUDE.md.