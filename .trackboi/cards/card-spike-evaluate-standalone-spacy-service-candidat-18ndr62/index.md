---
id: "card-spike-evaluate-standalone-spacy-service-candidat-18ndr62"
boardId: "default"
title: "Spike: evaluate standalone spaCy service candidates (HTTP, gRPC, native parser)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-runtime-decoupling-distributed-scaling-0q7iouw"
column: "backlog"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:59.472Z"
updatedAt: "2026-07-02T20:18:23.888Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Research spike, no production code. Evaluate three approaches from docs/architecture.md: (1) Python FastAPI/Flask HTTP microservice wrapping spaCy — lowest effort, highest operational overhead; (2) gRPC with protobuf schema matching `SyntacticClause` shape — lower latency, typed contract; (3) Ruby-native NLP parser (eliminating Python dependency entirely) — highest effort, lowest operational complexity. Criteria: output fidelity vs current `PassOneEngine`, latency at clause-level scale, operational complexity, horizontal scaling ceiling. Acceptance: `experiments/syntactic-service-spike.md` with a recommendation and the `SYNTACTIC_SERVICE_URL` feature-flag design.