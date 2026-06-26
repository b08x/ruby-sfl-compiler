---
id: "card-design-falcon-api-surface-and-scaffold-server-wi-0sadl2i"
boardId: "default"
title: "Design Falcon API surface and scaffold server with Bootstrap wiring"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-falcon-async-http-api-1vlq3hz"
column: "backlog"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:14:13.737Z"
updatedAt: "2026-06-26T04:14:13.737Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Design + scaffold (no route implementations). Define: (1) full API surface matching `docs/guides/modular-integration.md` — `POST /pipeline/compile`, `POST /retrieve`, `POST /synthesize`, `GET /workflows/:id/status`, `POST /workflows`; (2) request/response JSON schemas for each endpoint; (3) Bootstrap wiring — how `Bootstrap.call` is invoked at Falcon server startup (likely a new `require_api: true` mode); (4) add `falcon` and `async` to gemspec; (5) new `exe/sfl-api` binstub. Acceptance: `bundle exec sfl-api` starts without error on port 3001; `GET /health` returns `{status: "ok"}`.