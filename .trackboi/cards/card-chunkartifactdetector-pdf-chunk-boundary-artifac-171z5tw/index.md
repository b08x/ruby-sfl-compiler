---
id: "card-chunkartifactdetector-pdf-chunk-boundary-artifac-171z5tw"
boardId: "default"
title: "ChunkArtifactDetector — PDF chunk-boundary artifact detection"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-documentation-deep-dive-with-constraint-pinning-06mnjm7"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T03:48:38.082Z"
updatedAt: "2026-06-26T03:48:43.831Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
ChunkArtifactDetector detects PDF chunk boundaries that split clauses mid-sentence and flags them as structural artifacts (annotation_source: "chunk_artifact") rather than content signals.

IMPLEMENTED:
- lib/sfl/compiler/analysis/chunk_artifact_detector.rb — ChunkArtifactDetector class
- lib/sfl/compiler/analysis/documentation_analyzer.rb — flag_chunk_artifacts, rebuild_turns_with_chunk_artifacts, mark_chunk_artifact methods
- Types::AnnotationSource enum extended with "chunk_artifact" value (types.rb line 93)
- MarkdownFormatter counts chunk_artifact clauses separately from fallback/stub in Data Quality section
- DocumentationAnalyzer excludes chunk_artifact clauses from aggregate averages (reliable = clauses.reject chunk_artifact)
- Spec coverage: markdown_formatter_spec.rb counts chunk_artifacts, documentation_analyzer_spec.rb tests chunk_artifact detection