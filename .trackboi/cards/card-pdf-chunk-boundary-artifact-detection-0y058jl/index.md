---
id: "card-pdf-chunk-boundary-artifact-detection-0y058jl"
boardId: "default"
title: "PDF chunk-boundary artifact detection"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-documentation-deep-dive-with-constraint-pinning-06mnjm7"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:21:56.353Z"
updatedAt: "2026-06-25T07:13:56.503Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Build PDF chunk-boundary artifact detection for DocumentationAnalyzer.

PDFs are chunked into ~paragraph-sized sections. When a chunk boundary splits a clause mid-sentence (e.g., "The system was" on page 3 and "designed for scalability" on page 4), Pass 2 receives an ambiguous fragment and often defaults to 0.5 modality/tenor — a false measurement disguised as data.

Detection heuristic: flag clauses where the raw text ends without terminal punctuation (. ! ? ") AND the next chunk begins with lowercase or a continuation word (suggesting mid-sentence split). Alternatively: clauses where spaCy's sentence boundary detection identifies a sentence that spans the chunk boundary.

Requirements:
1. New module `Analysis::ChunkArtifactDetector` with `detect(clauses, chunk_boundaries)` returning indices of clauses likely affected.
2. Affected clauses get `annotation_source: "chunk_artifact"` (new provenance value, distinct from "fallback" and "stub").
3. The markdown formatter counts chunk_artifact clauses separately in Data Quality section. Like fallback/stub, these are excluded from aggregate scores.
4. RSpec tests: a known mid-sentence split is detected; a clean boundary (sentence ends at chunk end) is NOT flagged; pure markdown docs (no PDF chunking) never trigger the detector.

Acceptance: a 5-page PDF with known mid-page sentence breaks produces `chunk_artifact` annotations on the split clauses. Aggregate scores in the report exclude these. The Data Quality section states "N chunk-boundary artifacts excluded."