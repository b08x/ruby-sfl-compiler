---
id: "card-implement-standalone-syntactic-service-spacy-mic-1sk4u0z"
boardId: "default"
title: "Implement standalone syntactic service (spaCy microservice)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-runtime-decoupling-distributed-scaling-0q7iouw"
column: "backlog"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:14:08.093Z"
updatedAt: "2026-06-26T04:14:08.093Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
New `services/syntactic_service/` directory. Thin Python service (FastAPI or Flask) wrapping existing spaCy pipeline. Endpoint: `POST /parse` accepts `{text: String, model: String}`, returns `{clauses: SyntacticClause[]}` JSON matching current `PassOneEngine` output shape exactly. Dockerfile included. Acceptance: `curl -X POST localhost:8765/parse -d '{"text":"The server crashed."}' ` returns valid `SyntacticClause[]`; output is byte-for-byte equivalent to `PassOneEngine.new.parse("The server crashed.")` for the same model.