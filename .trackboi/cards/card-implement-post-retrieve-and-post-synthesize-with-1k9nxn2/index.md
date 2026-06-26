---
id: "card-implement-post-retrieve-and-post-synthesize-with-1k9nxn2"
boardId: "default"
title: "Implement POST /retrieve and POST /synthesize with stance filter params"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-falcon-async-http-api-1vlq3hz"
column: "backlog"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:14:22.651Z"
updatedAt: "2026-06-26T04:14:22.651Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Both fully inline (PostgreSQL + pgvector, no PyCall). `POST /retrieve`: `{query, filters: {min_modality, max_modality, min_tenor, max_tenor, mood, process_type}, limit}` → `Clause[]` with SFL annotations. `POST /synthesize`: `{query, filters, limit}` → `{answer, confidence, cited_clause_ids, clauses[]}`. Input validation at the API boundary (not inside the analyzer layer). Acceptance: `POST /retrieve` with `min_modality: 0.8` excludes low-modality clauses from response; `POST /synthesize` returns a cited answer with clause provenance.