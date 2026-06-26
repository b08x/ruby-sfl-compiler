---
id: "track-phase-2-semantic-convergence-entropy-collapse-de-1p60as8"
title: "Phase 2 — Semantic Convergence (Entropy Collapse Detection)"
slug: "phase-2-semantic-convergence-entropy-collapse-detection"
createdAt: "2026-06-26T04:11:41.080Z"
updatedAt: "2026-06-26T04:11:41.080Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Reuses existing pgvector + `Embedder` to detect stuck reasoning loops. Periodic checkpoint: embed the current Axiomatic summary, compare cosine similarity to the previous checkpoint. Similarity above threshold (e.g. 0.97) signals entropy collapse — the loop is not producing new information. Forces a circuit break with an audit log entry. Replaces the Gödel overflow as the runaway-loop safeguard. See ROADMAP.md §3.