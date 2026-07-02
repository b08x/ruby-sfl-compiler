---
id: "card-add-a-gush-workflow-equivalent-for-documentation-038ctzt"
boardId: "default"
title: "Add a Gush workflow equivalent for DocumentationAnalyzer"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-tui-overhaul-gush-sidekiq-backed-pycall-safe-0d27wx2"
column: "done"
rank: "yj1"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T00:40:20.740Z"
updatedAt: "2026-06-26T14:00:02.421Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Lower priority than the conversation path — only `ConversationAnalyzer` has a Gush decomposition today (`ConversationAnalysisWorkflow` + `CompileTurnJob`/`ReduceTurnsJob`). `sfl-analyze documentation ... --live` will hit the same PyCall-in-thread segfault as conversation did until `DocumentationAnalyzer` gets an equivalent workflow (one job per section instead of per turn). Mirror the same task breakdown used for the conversation plan (`docs/superpowers/plans/2026-06-24-gush-conversation-workflow.md`) rather than improvising a different shape.