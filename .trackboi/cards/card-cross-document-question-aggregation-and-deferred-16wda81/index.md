---
id: "card-cross-document-question-aggregation-and-deferred-16wda81"
boardId: "default"
title: "Cross-document question aggregation and deferred discovery"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-cross-document-g-del-encoded-question-graph-1bo8p33"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:24:27.401Z"
updatedAt: "2026-06-25T05:45:00.704Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Cross-document question graph: factor previous sprint, discover deferred questions, spawn follow-up.

The full multi-agent pipeline across documents. After analyzing multiple documents, factor the accumulated Gödel number to discover cross-document questions that emerged during analysis.

Requirements:
1. Method `CrossDocumentGraph.aggregate(sprint_graphs)` — takes multiple QuestionGraphs from different document analyses, merges them into a single cross-document graph.
2. New derived questions detected automatically: "Does the modality finding hold across doc types?" (depends on per-doc modality questions from ≥2 documents).
3. `CrossDocumentGraph.deferred_questions` — returns questions that couldn't be answered within a single document but require cross-document data.
4. Integration with kanban: when deferred questions are detected, auto-create child cards for follow-up analysis.
5. RSpec: (a) two document sprints with shared axiom produce cross-doc derived question, (b) single document produces no deferred questions, (c) three documents with divergent findings produce a "reconciliation needed" question.

Acceptance: analyzing a formal API doc and an informal blog post produces per-doc graphs. Aggregating them reveals a derived question "Is the modality gap between doc types statistically meaningful?" that wasn't in either individual analysis.