---
id: "track-human-in-the-loop-annotation-review-0fn8s9p"
title: "Human-in-the-Loop Annotation Review"
slug: "human-in-the-loop-annotation-review"
createdAt: "2026-07-03T05:29:11.420Z"
updatedAt: "2026-07-03T05:29:47.510Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Make human review a first-class pipeline stage: clauses the pipeline could not confidently annotate (annotation_source fallback/stub, `:fuzzy` classification hits) enter a review queue where a human can accept, re-annotate (single-clause Pass 2 recompile, cache-bypassed), or reject. From the TUI-as-compiler-view vision (2026-07-03 kaizen analysis): "the compiler admits uncertainty rather than pretending every clause has a single correct interpretation." Structural prerequisite: a review-status data model — the `clauses`/`interpersonal_payloads` tables have no review state today, and the TUI is read-only by design. Seed UI shipped: `TUI::EvidencePane`'s "Needs attention" list is exactly the future queue's candidate set.