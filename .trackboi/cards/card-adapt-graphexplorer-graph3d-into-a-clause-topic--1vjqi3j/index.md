---
id: "card-adapt-graphexplorer-graph3d-into-a-clause-topic--1vjqi3j"
boardId: "default"
title: "Adapt GraphExplorer/Graph3D into a clause/topic/document Corpus Browser over /retrieve"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "doing"
rank: "U"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:41:43.987Z"
updatedAt: "2026-07-03T07:37:45.814Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Depends on the GraphContext/Falcon wiring card AND the Multi-Source Corpus Bridging track (all 3 of its cards — source_type column, chat export loaders, CanvasLoader/format widening) — without those, "Corpus Browser" would only ever show vault markdown/PDF/image content, not the chat exports (Claude.ai/ChatGPT/Mistral LeChat) ConvoWorkbench was originally built around.

Repurpose `GraphExplorer.tsx`/`Graph3D.tsx`/`GraphInsights.tsx` (react-force-graph-3d) to visualize sfl-compiler's actual graph: documents → clauses → topics, with per-clause SFL annotation (ideational: process_type/participants/circumstances; interpersonal: mood/modality_weight/tenor/speaker_attitude) shown on node selection, an `annotation_source` badge (llm/fallback/stub) per clause node, **and a `source_type` filter/facet** (chat_claude/chat_chatgpt/chat_mistral/chat_native vs. vault_markdown/vault_pdf/vault_image/vault_canvas/vault_docx/etc.) so the browser can show "everything" or narrow to one source domain.

Requires a new `GET /clauses` endpoint in the Falcon API (paginated, filterable by document_id, interpersonal fields, and source_type). Acceptance: browse a 100-clause document, filter to `annotation_source: llm` only, see the correct subset rendered; separately, filter by `source_type` and confirm chat-export and vault-document clauses are both browsable through the same UI.