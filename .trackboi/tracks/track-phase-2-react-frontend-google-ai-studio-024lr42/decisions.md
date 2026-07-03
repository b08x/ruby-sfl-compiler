# Decisions

## [accepted] Defer React/Falcon frontend to Phase 3

Deferred 2026-07-02. Phase 2 focus is backend pipeline correctness (Gush parallelism, CognitiveGas, Rolling Synthesis, ConvergenceDetector) — all now shipped. React scaffold and Falcon API backend will be Phase 3 work once the core pipeline is validated against real documents. No cards in this track should be moved to todo/doing until Phase 3 is opened.

## [accepted] Adopt and refactor ConvoWorkbench instead of building fresh in Google AI Studio

Considered: (a) keep the Google AI Studio from-scratch scaffold plan, (b) adopt `/home/b08x/WorkspaceV3/ConvoWorkbench` — a separate, already-built React 19 + Vite + Tailwind app for reviewing/rating LLM conversations — and refactor it to consume sfl-compiler's Falcon API. Chose (b): ConvoWorkbench's UI shell (nav, review queue, graph explorer, dashboard, per-task model settings) already matches this track's Primary/Secondary view shape, but its data/LLM layer is a worse, client-side, unpersisted, API-key-in-browser reimplementation of things sfl-compiler's Ruby backend already does (TopicModeler, SprintWorkflow's Achilles/Tortoise/Genie, DSPy.rb provider config). The refactor strips that layer and repoints the UI at the Falcon API. This does not reopen the "Defer to Phase 3" decision — new cards stay in backlog; it only changes what "doing the React frontend" will mean when Phase 3 opens, from writing from scratch to adapting a known-working shell.
