---
id: "card-cli-integration-sprint-id-flag-and-sprint-subcom-0tc5jah"
boardId: "default"
title: "CLI integration: --sprint-id flag and sprint subcommand"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-cross-document-g-del-encoded-question-graph-1bo8p33"
column: "todo"
rank: "yjU"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:24:26.341Z"
updatedAt: "2026-06-26T04:14:46.114Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
CLI integration: `--sprint-id` flag and `sfl-analyze sprint` subcommand.

**PARTIALLY DONE**: The `--sprint-id ID` flag already exists on `sfl-analyze documentation` (cli.rb line 47, 125) and attaches a Gödel-encoded question-graph footer to the report. What remains:

Wire the QuestionGraph and SprintOrchestrator into the CLI so users can create, query, and resume sprints.

Remaining requirements:
1. New subcommand `sfl-analyze sprint <action> [args]` with actions: `start "RQ"`, `status <sprint_id>`, `resume <sprint_id>`, `list`.
2. `sfl-analyze sprint start "Do formal docs have higher modality?"` — creates a new sprint, outputs the sprint ID and initial Gödel number.
3. `sfl-analyze sprint status <id>` — factors the Gödel number, shows which questions are resolved vs. deferred.
4. `sfl-analyze sprint resume <id>` — loads the previous sprint's question graph, constructs next sprint via `SprintOrchestrator#next_sprint_graph`.
5. Sprint state stored in `sprints` table (id, gödel_number, rq_text, started_at, status) — add migration.
6. RSpec: CLI integration tests for each subcommand; `--sprint-id` flag on conversation (not just documentation) produces report with Gödel footer.

Acceptance: `sfl-analyze sprint start "test RQ"` creates a sprint record. `sfl-analyze sprint status <id>` shows question breakdown. `sfl-analyze conversation chat.jsonl --sprint-id <id>` produces a report with Gödel number in footer.