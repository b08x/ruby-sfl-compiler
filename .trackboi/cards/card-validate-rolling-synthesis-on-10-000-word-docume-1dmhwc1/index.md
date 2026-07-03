---
id: "card-validate-rolling-synthesis-on-10-000-word-docume-1dmhwc1"
boardId: "default"
title: "Validate Rolling Synthesis on 10,000-word document: SFL metadata preserved through compression"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-rolling-synthesis-fractal-graphs-0bhnviv"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:15.106Z"
updatedAt: "2026-07-03T15:35:45.182Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Integration validation (not a unit test). Run the full rolling synthesis pipeline against a real 10,000-word incident report or long document. Confirm: (1) Axiomatic summary retains SFL metadata (process_type distribution within 10% of raw clause aggregate); (2) stance filters applied to summarized evidence produce equivalent retrieval quality to raw clause retrieval (measured by `min_modality`/`min_tenor` filter hit rate); (3) context window does not grow proportionally with document length. Acceptance: documented comparison report in `experiments/`.