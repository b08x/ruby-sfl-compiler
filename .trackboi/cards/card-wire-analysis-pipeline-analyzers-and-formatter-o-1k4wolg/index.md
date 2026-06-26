---
id: "card-wire-analysis-pipeline-analyzers-and-formatter-o-1k4wolg"
boardId: "default"
title: "Wire analysis pipeline, analyzers, and formatter output stack"
parentId: "None"
scope: {"kind":"project","ref":"global"}
trackId: null
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-24T18:14:57.309Z"
updatedAt: "2026-06-26T03:48:18.652Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Extend the analysis layer end-to-end: ConversationAnalyzer and DocumentationAnalyzer glue pipelines to persisted clauses; TenorTracker detects tenor shifts per turn; SpeakerProfiler aggregates speaker-level stance; CorrelationAnalyzer maps process types to tenor/modality. Add formatter/report writer paths and ensure Data Quality sections reflect annotation_source coverage.