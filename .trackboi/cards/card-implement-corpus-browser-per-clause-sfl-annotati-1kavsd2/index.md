---
id: "card-implement-corpus-browser-per-clause-sfl-annotati-1kavsd2"
boardId: "default"
title: "Implement Corpus Browser: per-clause SFL annotations with annotation_source provenance"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:14:35.694Z"
updatedAt: "2026-07-03T05:41:28.876Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
View for browsing ingested documents by clause. Shows: document list, per-clause text, ideational payload (process_type, participants, circumstances), interpersonal payload (mood, modality_weight, tenor, speaker_attitude), annotation_source badge (llm / fallback / stub / chunk_artifact). Filtering by annotation_source and by stance ranges. Requires a new `GET /clauses` endpoint in the Falcon API (paginated, filterable by document_id and interpersonal fields). Acceptance: can browse a 100-clause document, filter to `annotation_source: llm` only, and see the correct subset.