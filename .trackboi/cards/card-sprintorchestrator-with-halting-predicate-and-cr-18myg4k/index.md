---
id: "card-sprintorchestrator-with-halting-predicate-and-cr-18myg4k"
boardId: "default"
title: "SprintOrchestrator with halting predicate and cross-session persistence"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-cross-document-g-del-encoded-question-graph-1bo8p33"
column: "todo"
rank: "yj3"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:24:25.279Z"
updatedAt: "2026-06-25T01:51:42.505Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
SprintOrchestrator: manage sprint state, halting predicate, cross-session persistence.

The orchestrator ties the QuestionGraph to actual analysis runs. It tracks what was asked, what was answered, what was deferred, and decides when to stop.

Requirements:
1. New file `lib/sfl/compiler/sprint_orchestrator.rb` with class `SFL::Compiler::SprintOrchestrator`.
2. `#start_sprint(questions:)` — creates a new QuestionGraph, stores it (in memory or DB), sets sprint metadata (started_at, budget).
3. `#complete_sprint(answer_graph:)` — updates the QuestionGraph with answers, computes Gödel number.
4. `#halt?(current_graph)` — returns true if: (a) RQ unchanged between last two sprints, OR (b) budget consumed (>80% token/call limit), OR (c) all questions answered (no deferred).
5. `#next_sprint_graph(previous_gödel)` — factors the previous Gödel number, identifies unresolved questions, constructs a new QuestionGraph with derived questions.
6. Budget tracking: accepts `max_tokens:` or `max_calls:` param; tracks consumption via simple counter.
7. RSpec: (a) sprint with all questions answered halts immediately, (b) sprint with unresolved questions + stable RQ halts (no infinite loop), (c) sprint with budget exceeded halts even if questions remain, (d) `next_sprint_graph` correctly factors and constructs derived questions.

Acceptance: orchestrator runs 3 sprints on a 3-question graph where q3 depends on q1+q2 answers. Sprint 1 answers q1,q2. Sprint 2 factors G_1, discovers q3 is now answerable. Sprint 3 halts because all questions resolved.