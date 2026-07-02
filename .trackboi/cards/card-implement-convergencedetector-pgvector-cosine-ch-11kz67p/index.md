---
id: "card-implement-convergencedetector-pgvector-cosine-ch-11kz67p"
boardId: "default"
title: "Implement ConvergenceDetector: pgvector cosine checkpoint for reasoning loop health"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-semantic-convergence-entropy-collapse-de-1p60as8"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:33.511Z"
updatedAt: "2026-07-02T20:01:06.326Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
New `lib/sfl/compiler/convergence_detector.rb`. Uses existing `Embedder` class — no new embedding infrastructure. Interface: `ConvergenceDetector.new(embedder:, threshold: 0.97, checkpoint_every: N_cycles)`. `#check(axiomatic_summary_text)` embeds the summary, compares cosine similarity to previous checkpoint embedding, returns `{converged: bool, similarity: Float, cycles: Integer}`. When `converged: true`, caller forces circuit break. Writes audit log entry with similarity, cycle count, clauses consumed. Acceptance: unit spec with a fixed embedding pair above/below threshold; integration test with a deliberately repetitive summary sequence.