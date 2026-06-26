---
id: "card-implement-graceful-summarization-on-cognitive-ga-1fle8fh"
boardId: "default"
title: "Implement graceful summarization on Cognitive Gas exhaustion (Rolling Synthesis trigger)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-cognitive-gas-semantic-circuit-breaker-0xefy41"
column: "backlog"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:28.167Z"
updatedAt: "2026-06-26T04:13:28.167Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Wire budget exhaustion to Rolling Synthesis instead of a hard stop. When `CognitiveGas` trips, the `rescue CircuitBrokenException` block in `PassTwoEngine` should: (1) trigger an `IntermediateGenieJob` to compress the clauses processed so far; (2) reset the gas budget; (3) continue processing the remaining clauses against the fresh budget. Depends on `IntermediateGenieJob` being implemented. Acceptance: test with a 500-clause document and a tight budget — confirm processing completes (no crash), `annotation_source` provenance preserved on all clauses, intermediate Axiomatic summary record exists in DB.