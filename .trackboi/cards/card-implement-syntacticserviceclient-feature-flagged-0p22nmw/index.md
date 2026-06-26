---
id: "card-implement-syntacticserviceclient-feature-flagged-0p22nmw"
boardId: "default"
title: "Implement SyntacticServiceClient feature-flagged via SYNTACTIC_SERVICE_URL"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-runtime-decoupling-distributed-scaling-0q7iouw"
column: "backlog"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:14:04.131Z"
updatedAt: "2026-06-26T04:14:04.131Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
New `lib/sfl/compiler/pass_one/syntactic_service_client.rb`. Speaks to the standalone syntactic service (HTTP or gRPC, per spike recommendation). `PassOneEngine` checks `ENV["SYNTACTIC_SERVICE_URL"]` — when set, delegates to `SyntacticServiceClient`; when absent, falls back to existing PyCall path. Output contract: identical `Array<SyntacticClause>` shape regardless of which path executed. Acceptance: both code paths pass the same `pass_one_engine_spec.rb` examples; `SYNTACTIC_SERVICE_URL=http://localhost:8765` routes to client without touching PyCall.