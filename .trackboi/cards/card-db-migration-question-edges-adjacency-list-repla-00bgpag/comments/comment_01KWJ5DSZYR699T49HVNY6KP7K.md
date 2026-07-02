---
id: "comment_01KWJ5DSZYR699T49HVNY6KP7K"
cardId: "card-db-migration-question-edges-adjacency-list-repla-00bgpag"
createdAt: "2026-07-02T19:38:23.102Z"
updatedAt: "2026-07-02T19:38:23.102Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in commit b37e764.

`QuestionEdgeRepository` (`lib/sfl/compiler/storage/question_edge_repository.rb`):
- `store(graph)`: idempotent — deletes existing edges for the node set, then inserts parent_id/child_id/depth rows in one transaction
- `reconstruct(questions)`: queries `WHERE child_id IN (ids)`, rebuilds dependency lists, returns a fresh `QuestionGraph` — no BIGINT ceiling
- `reachable(start_id)`: recursive CTE for transitive closure when full graph is not in memory

DB migration (`Migrator#run_all`): `create_question_edges_table` adds `question_edges` with btree unique index on `(parent_id, child_id)` and index on `child_id`.

`question_graph.rb` retained as Phase 1 reference (in-memory only, no Gödel column was ever in the DB).

6 specs: store edges + depths, reconstruct 10-node chain (depth=9 verified), diamond DAG, isolated node, reachable CTE. 585 total examples, 0 failures.