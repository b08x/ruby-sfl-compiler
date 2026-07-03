---
id: "card-strip-convoworkbench-s-client-side-data-llm-laye-0ecj1yh"
boardId: "default"
title: "Strip ConvoWorkbench's client-side data/LLM layer, wire GraphContext to Falcon API"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:41:39.985Z"
updatedAt: "2026-07-03T06:04:52.356Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Foundational refactor — everything else in this track depends on it. In `/home/b08x/WorkspaceV3/ConvoWorkbench`:

**Remove**: `src/lib/graph/builder.ts` (Claude/ChatGPT export parsing), `src/lib/graph/topic_extraction.ts` + `embeddings.ts` (client TF-IDF/LLM topic clustering), `src/lib/providers/*` (gemini/groq/mistral/ollama/openrouter browser SDKs — API keys currently live client-side), `src/lib/distillation/orchestrator.ts`, `src/lib/trajectory/compiler.ts`.

**Replace**: `src/contexts/GraphContext.tsx`'s local `useReducer` (currently unpersisted — a page refresh loses all state) with data fetched from the Falcon API (`lib/sfl/compiler/api/server.rb`). `ConvoGraph`'s shape (`messages`/`conversations`/`topics`/`trajectories`/`skills`) needs a mapping layer onto sfl-compiler's `AnnotatedClause`/`ConversationTurn`/topic-model output — not a 1:1 rename, since ConvoWorkbench's rating rubric (correctness/tone/format) is a different axis than SFL's annotation_source/mood/tenor.

**Keep as-is for now**: `src/types/provider.ts`'s `TaskModelConfig`/`TaskType` shape and `SettingsView` — reference design for the separate Model Provider Configuration track, not this refactor's concern.

Acceptance: `npm run dev` renders the shell with zero client-side LLM calls; all conversation/clause data comes from a running Falcon server.