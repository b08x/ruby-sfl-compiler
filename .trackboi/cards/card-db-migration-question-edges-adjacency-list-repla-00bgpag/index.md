---
id: "card-db-migration-question-edges-adjacency-list-repla-00bgpag"
boardId: "default"
title: "DB migration: question_edges adjacency list (replace Gödel integer column)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-rolling-synthesis-fractal-graphs-0bhnviv"
column: "backlog"
rank: "yU"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:11.280Z"
updatedAt: "2026-06-26T04:13:11.280Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
New `question_edges` table: `parent_id → child_id, depth, created_at`. Recursive CTEs for reachability and topological ordering. Remove the single-integer Gödel encoding from `QuestionGraph`'s persistence layer (keep `question_graph.rb` as a Phase 1 reference, do not delete). Add GiST or btree index on `(parent_id, child_id)`. Acceptance: `QuestionGraph` can be reconstructed from `question_edges` rows with no BIGINT overflow ceiling; test at 10+ node depth.