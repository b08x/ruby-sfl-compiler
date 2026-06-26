---
id: "card-documentationanalyzer-low-confidence-threshold-c-0zq23kz"
boardId: "default"
title: "DocumentationAnalyzer low_confidence threshold + chunk_artifact exclusion"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-documentation-deep-dive-with-constraint-pinning-06mnjm7"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T03:50:26.615Z"
updatedAt: "2026-06-26T03:50:44.523Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
DocumentationAnalyzer enforces minimum clause threshold and excludes chunk-artifact clauses from aggregate scores.

IMPLEMENTED:
- MIN_CLAUSE_THRESHOLD = 30 (DocumentationAnalyzer constant). Documents producing <30 clauses get metadata[:low_confidence] = true.
- metadata[:low_confidence_threshold] set to 30 for downstream consumers.
- chunk_artifact clauses (annotation_source: "chunk_artifact") excluded from aggregate averages via reliable = clauses.reject { |c| c.interpersonal.annotation_source == "chunk_artifact" }.
- MarkdownFormatter renders low_confidence banner with clause count and threshold when low_confidence is true.
- NarrativeGenerator includes low_confidence_notice in narrative when metadata["low_confidence"] is true.
- Spec coverage: documentation_analyzer_spec.rb tests low_confidence at 29 clauses (triggers) vs 31 (does not), chunk_artifact detection, and markdown_formatter_spec.rb tests banner rendering.