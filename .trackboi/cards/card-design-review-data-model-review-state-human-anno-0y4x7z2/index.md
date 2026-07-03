---
id: "card-design-review-data-model-review-state-human-anno-0y4x7z2"
boardId: "default"
title: "Design review data model: review state, \"human\" annotation_source, audit trail"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-human-in-the-loop-annotation-review-0fn8s9p"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:29:29.750Z"
updatedAt: "2026-07-03T10:54:20.635Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Decide and migrate: columns on `interpersonal_payloads` vs. a separate `annotation_reviews` table (recommended in track brief — preserves original machine annotation alongside human override). Extend the `annotation_source` enum with `"human"` and audit every consumer of that enum: formatters' Data Quality sections, `annotation_coverage` stats, `QualityScorer` reliability weighting, EvidencePane's flagged predicate (human-reviewed should stop being "needs attention"). Acceptance: migration + Types enum + all consumers handle the new value, spec-covered.