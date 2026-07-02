---
id: "card-implement-intermediategeniejob-compress-working--0s0m4br"
boardId: "default"
title: "Implement IntermediateGenieJob: compress working memory → Axiomatic summary"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-rolling-synthesis-fractal-graphs-0bhnviv"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:07.001Z"
updatedAt: "2026-07-02T20:00:58.365Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
New `lib/sfl/compiler/jobs/intermediate_genie_job.rb`. Gush::Job that receives a batch of `AnnotatedClause` IDs, runs a `SynthesisSignature`-based compression via `SprintRoleJob` (Genie role), writes an Axiomatic summary record, and outputs the summary ID for the next rolling synthesis cycle. Originals remain in PostgreSQL; only the summary ID advances. Acceptance: job runs against a real 100-clause document, Axiomatic summary record contains SFL metadata aggregates, stance filters applied to summary produce equivalent results to applying them to raw clauses.