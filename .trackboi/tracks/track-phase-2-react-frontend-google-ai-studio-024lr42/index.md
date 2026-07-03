---
id: "track-phase-2-react-frontend-google-ai-studio-024lr42"
title: "Phase 2 — React Frontend (Google AI Studio)"
slug: "phase-2-react-frontend-google-ai-studio"
createdAt: "2026-06-26T04:12:27.817Z"
updatedAt: "2026-07-03T05:44:44.482Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Plan changed 2026-07-03: adopt and refactor `/home/b08x/WorkspaceV3/ConvoWorkbench` instead of scaffolding fresh in Google AI Studio.** Codebase-memory review found ConvoWorkbench (React 19 + Vite + Tailwind, own separate project) already has a working shell for exactly this track's shape: a review queue (list → detail → rating panel), a graph explorer (react-force-graph-3d), a dashboard, an import wizard, and — bonus — a per-task model-provider settings screen that answers the separate Model Provider Configuration track's open UI question.

**What's reusable**: `AppShell`/`Sidebar` nav shell, the shadcn-style component kit (button/card/checkbox/input/label/select/slider/tabs), `ReviewView`+`ConversationList`+`ConversationViewer`+`RatingPanel` (list/detail/decision-panel pattern), `GraphExplorer`/`Graph3D`/`GraphInsights`, `DashboardView`, `SettingsView` + `TaskModelConfig`/`TaskType` provider-config shape.

**What gets stripped** (client-side reimplementations of things sfl-compiler's Ruby backend already does, more rigorously, server-side): `lib/graph/builder.ts` (Claude/ChatGPT export parsing — sfl-compiler has its own conversation JSONL + MarkdownLoader formats), `lib/graph/topic_extraction.ts`+`embeddings.ts` (client TF-IDF/LLM clustering — superseded by `TopicModeler`'s calibrated k-independent dominance gate), `lib/providers/*` (gemini/groq/mistral/ollama/openrouter — browser-side API keys are a real risk; DSPy.rb+Bootstrap already own provider config server-side), `lib/distillation/orchestrator.ts`+`lib/trajectory/compiler.ts` (client weak/strong two-pass distillation — superseded by `SprintWorkflow`'s Achilles→Tortoise→Genie). All LLM calls and data get repointed at the Falcon API (`lib/sfl/compiler/api/server.rb`) instead of local browser state (which today has zero persistence — a refresh loses everything).

See new cards for the concrete migration steps. Old cards for building from scratch are closed (see comments) — the equivalent work now happens by adapting a codebase, not authoring one.