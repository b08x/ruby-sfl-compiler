---
id: "card-adapt-graphexplorer-graph3d-into-a-clause-topic--1vjqi3j"
boardId: "default"
title: "Adapt GraphExplorer/Graph3D into a clause/topic/document Corpus Browser over /retrieve"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "backlog"
rank: "yyU"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:41:43.987Z"
updatedAt: "2026-07-03T05:41:43.987Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Depends on the GraphContext/Falcon wiring card. Repurpose `GraphExplorer.tsx`/`Graph3D.tsx`/`GraphInsights.tsx` (react-force-graph-3d) to visualize sfl-compiler's actual graph: documents → clauses → topics, with per-clause SFL annotation (ideational: process_type/participants/circumstances; interpersonal: mood/modality_weight/tenor/speaker_attitude) shown on node selection, and an `annotation_source` badge (llm/fallback/stub) per clause node. Requires a new `GET /clauses` endpoint in the Falcon API (paginated, filterable by document_id and interpersonal fields — same requirement the old "Corpus Browser" card specified). Filtering by annotation_source and stance ranges (modality/tenor). Acceptance: browse a 100-clause document, filter to `annotation_source: llm` only, see the correct subset rendered.