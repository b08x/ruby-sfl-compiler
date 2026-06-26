---
id: "card-questiongraph-class-with-g-del-encoded-dag-073a9lw"
boardId: "default"
title: "QuestionGraph class with Gödel-encoded DAG"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-cross-document-g-del-encoded-question-graph-1bo8p33"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:24:24.225Z"
updatedAt: "2026-06-25T04:54:01.509Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implement the QuestionGraph class with Gödel encoding.

Core data structure for the multi-agent sprint orchestration system. Encodes question-dependency DAGs as a single integer via prime factorization, recoverable without metadata.

Requirements:
1. New file `lib/sfl/compiler/question_graph.rb` with class `SFL::Compiler::QuestionGraph`.
2. Constructor accepts an array of question hashes: `{ id:, text:, dependencies: [] }`.
3. Axiomatic questions (no dependencies) get the next prime: 2, 3, 5, 7...
4. Derived questions get `next_seed_prime × product(dependency_primes)`: 13×2=26, 17×6=102... (seed-prime corrected to avoid collision when single dependency).
5. `#gödel_number` — product of all question primes.
6. `#factor(n = gödel_number)` — prime factorization returning `{ prime => count }`.
7. `#decode(n = gödel_number)` — recovers the full question set from factorization.
8. `#consistent?` — `decode.sort == questions.keys.sort` confirms encoding integrity.
9. RSpec: encode a 5-question graph, factor it, decode matches original. Edge case: single-question graph (gödel = prime itself). Edge case: deeply nested dependency chain (q depends on q' which depends on q'').

Acceptance: `QuestionGraph.new([{id: :q1, text: "...", dependencies: []}, {id: :q4, text: "...", dependencies: [:q1]}]).gödel_number` produces a composite integer. `.factor` then `.decode` recovers `[:q1, :q4]`.