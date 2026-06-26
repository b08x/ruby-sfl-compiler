---
id: "card-questiongraph-crossdocumentgraph-g-del-encoded-d-0jmm4dy"
boardId: "default"
title: "QuestionGraph + CrossDocumentGraph — Gödel-encoded DAG and cross-doc merging"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-cross-document-g-del-encoded-question-graph-1bo8p33"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T03:48:56.497Z"
updatedAt: "2026-06-26T03:49:05.003Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
QuestionGraph encodes question-dependency DAGs as a single Gödel number via prime factorization. CrossDocumentGraph merges per-document question graphs and auto-detects cross-document findings.

IMPLEMENTED:
- lib/sfl/compiler/question_graph.rb — QuestionGraph class with gödel_number, factor, decode, consistent? methods. Seed-prime corrected encoding: axiomatic questions get raw primes, derived questions get seed × product(dependencies).
- lib/sfl/compiler/cross_document_graph.rb — CrossDocumentGraph class, aggregates multiple QuestionGraphs, namespaces ids, detects derived questions, reconciles numeric findings (≥0.3 threshold).
- CLI --sprint-id flag on documentation command attaches Gödel-encoded footer to report (cli.rb line 47, 125).
- Spec: sprint_workflow_spec.rb verifies end-to-end SprintWorkflow with Gödel encoding.
- Note: BIGINT overflow at 6-7 deep nodes is intentional implicit circuit breaker (documented in docs/architecture.md). SprintOrchestrator (separate card, still todo) layers above this.