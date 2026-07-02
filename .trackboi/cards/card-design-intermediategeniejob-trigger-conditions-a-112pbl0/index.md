---
id: "card-design-intermediategeniejob-trigger-conditions-a-112pbl0"
boardId: "default"
title: "Design IntermediateGenieJob: trigger conditions and Axiomatic summary schema"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-rolling-synthesis-fractal-graphs-0bhnviv"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:02.306Z"
updatedAt: "2026-07-02T20:00:35.969Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Design work (no implementation). Decide: (1) trigger conditions — section breaks, topic shifts detected via tenor delta, or configurable token threshold; (2) what an Axiomatic summary contains — SFL metadata shape (process_type distribution, avg modality/tenor, mood histogram, key participants) vs. raw clause text; (3) how the summary carries forward as the axiomatic base for the next reasoning cycle; (4) where intermediate summaries are stored (new `axiomatic_summaries` table or reuse `clauses` with a flag). Acceptance: ADR written, schema drafted, `IntermediateGenieJob` interface defined.