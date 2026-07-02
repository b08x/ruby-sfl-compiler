---
id: "card-implement-post-pipeline-compile-annotatedclause--1hr5u53"
boardId: "default"
title: "Implement POST /pipeline/compile → AnnotatedClause[] (async via Sidekiq or inline)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-falcon-async-http-api-1vlq3hz"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:14:18.061Z"
updatedAt: "2026-07-02T19:09:11.877Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Two modes: (1) `sync: true` param — runs `Pipeline.compile` inline (single clause, no PyCall thread risk in Falcon's fiber model); (2) default async — dispatches `CompileTurnJob` via Sidekiq, returns `{workflow_id:, status: "queued"}`. PyCall is only invoked in the Sidekiq worker process, never in the Falcon fiber. Acceptance: `POST /pipeline/compile` with `sync: true` returns `AnnotatedClause[]` JSON; async mode returns workflow_id that resolves via `GET /workflows/:id/status`.