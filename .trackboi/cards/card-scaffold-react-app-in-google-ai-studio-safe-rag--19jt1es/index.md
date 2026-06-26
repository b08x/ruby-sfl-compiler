---
id: "card-scaffold-react-app-in-google-ai-studio-safe-rag--19jt1es"
boardId: "default"
title: "Scaffold React app in Google AI Studio: Safe RAG Hypothesis Validator view"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "backlog"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:14:31.164Z"
updatedAt: "2026-06-26T04:14:31.164Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Primary view — the core hypothesis demonstration surface. Side-by-side comparison: same query, same corpus, WITHOUT stance filters vs. WITH configurable stance filters (modality slider, tenor slider, mood selector). Each column shows: filtered evidence clauses with SFL annotations, then LLM-generated answer. Consumes `POST /retrieve` and `POST /synthesize` from the Falcon API. Acceptance: user can adjust `min_modality` slider from 0 to 1, hit Submit, and see different evidence sets and answers in each column.