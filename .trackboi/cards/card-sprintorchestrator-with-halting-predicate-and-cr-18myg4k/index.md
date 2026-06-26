---
id: "card-sprintorchestrator-with-halting-predicate-and-cr-18myg4k"
boardId: "default"
title: "SprintOrchestrator with halting predicate (academic/teaching context only)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-cross-document-g-del-encoded-question-graph-1bo8p33"
column: "backlog"
rank: "yj3"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:24:25.279Z"
updatedAt: "2026-06-26T05:42:16.773Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Deferred — only implement if needed for an academic write-up, paper, or teaching demonstration.**

The existing `QuestionGraph` + `CrossDocumentGraph` + documentation report footer (`Sprint G_N = 6300`) already demonstrate the Gödel-encoded approach sufficiently. The BIGINT overflow at 6-7 nodes IS the thesis, not a bug — a working demonstration of "the system provably cannot ask too many questions without hitting a representational limit." That point is made without a full orchestrator.

Phase 2 (Rolling Synthesis + `ConvergenceDetector` wired into a new halt predicate) supersedes the Gödel-based halting logic entirely. Building a production SprintOrchestrator on top of Gödel encoding before Phase 2 is ready would be engineering a full abstraction layer over a mechanism that is deliberately replaced.

**If implemented** (academic context only): `lib/sfl/compiler/sprint_orchestrator.rb`. Manages sprint state, halting predicate (RQ unchanged OR budget exhausted OR all questions answered), `#next_sprint_graph` that factors the previous Gödel number to construct a new `QuestionGraph` with derived questions. Budget tracking via `max_tokens:`/`max_calls:` counters. Keep scope minimal — no persistence layer, no Redis state.