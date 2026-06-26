---
id: "track-phase-2-falcon-async-http-api-1vlq3hz"
title: "Phase 2 — Falcon/Async HTTP API"
slug: "phase-2-falcon-async-http-api"
createdAt: "2026-06-26T04:12:12.693Z"
updatedAt: "2026-06-26T04:12:12.693Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Backend HTTP API layer exposing the SFL pipeline, retriever, and synthesizer as async endpoints. Required for the React frontend and for the "modular middleware" positioning in `docs/guides/modular-integration.md`. Built on Falcon + async gems so the server can handle concurrent pipeline compile and retrieval requests without the PyCall threading restriction (each request handled by a separate fiber/process).