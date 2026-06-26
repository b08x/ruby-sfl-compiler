---
id: "card-cli-integration-sprint-id-flag-and-sprint-subcom-0tc5jah"
boardId: "default"
title: "CLI: extend --sprint-id to conversation command"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-cross-document-g-del-encoded-question-graph-1bo8p33"
column: "todo"
rank: "yjU"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:24:26.341Z"
updatedAt: "2026-06-26T05:42:23.298Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Scope narrowed (2026-06-26):** The full `sfl-analyze sprint` subcommand (start/status/resume/list) and `sprints` DB migration are deferred — they built on the Gödel SprintOrchestrator which is now backlogged as academic-only. Phase 2 will introduce a proper sprint subcommand backed by Rolling Synthesis, not Gödel encoding.

**Remaining in scope:** `--sprint-id` flag on `sfl-analyze conversation` command (currently documentation-only). This is wiring the already-shipped infrastructure to a second command — low risk, no new abstractions. The `DocumentationAnalyzer` sprint footer path already exists; `ConversationAnalyzer` needs the same `sprint_id:` param threaded through.

Acceptance: `sfl-analyze conversation sample.jsonl --sprint-id my-sprint` produces a conversation report with a `Sprint G_N` footer identical in structure to the documentation report footer (commit cb34388).