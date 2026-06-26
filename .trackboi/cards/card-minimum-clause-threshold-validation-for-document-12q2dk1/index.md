---
id: "card-minimum-clause-threshold-validation-for-document-12q2dk1"
boardId: "default"
title: "Minimum-clause threshold validation for documentation analysis"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-documentation-deep-dive-with-constraint-pinning-06mnjm7"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:21:55.292Z"
updatedAt: "2026-06-25T06:52:36.164Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Add minimum-clause threshold validation to DocumentationAnalyzer.

Documents producing fewer than 30 clauses are statistically unreliable for aggregate modality/tenor scoring. Currently the pipeline produces reports regardless of sample size.

Requirements:
1. `DocumentationAnalyzer#analyze` tracks total clause count; if < 30, sets `result.metadata[:low_confidence] = true` and `result.metadata[:clause_count]` explicitly.
2. The markdown formatter renders a "Low Confidence" banner when `low_confidence: true` (similar to existing Data Quality section but more prominent).
3. The narrative generator includes the low-confidence marker in its digest so narratives from small corpora carry the caveat.
4. RSpec tests: a document producing 29 clauses triggers the banner; a document producing 31 does not; a document producing 0 clauses errors gracefully with a message about insufficient data.

Acceptance: `sfl-analyze documentation short_doc.md --store` produces output with visible "Low Confidence: 29 clauses (minimum 30 recommended)" and the narrative explicitly states the analysis is based on a small sample.