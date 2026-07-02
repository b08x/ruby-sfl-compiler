---
id: "card-design-model-provider-config-schema-verify-tty-c-1lds93z"
boardId: "default"
title: "Design model-provider config schema + verify tty-config API via Context7"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-model-provider-configuration-1xkfb58"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T04:35:31.146Z"
updatedAt: "2026-07-02T20:23:20.115Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
First card on this track — design, not implementation.

## Scope
1. Resolve `tty-config` via Context7 and confirm its real API (XDG path resolution, nested key read/write, validation hooks) before any code is written — this project's standing practice is to verify gem APIs via Context7 rather than gem source for integration questions.
2. Decide the per-task key granularity: literal call sites (`pass_two`, `narrative`, `achilles`, `tortoise`, `crab`, `genie`) vs. a smaller durable role set (`annotation`, `generation`, `verification`). See track brief's "Open questions."
3. Decide where this config registry lives relative to `Bootstrap` (the project's documented single ENV-reader) — either inside Bootstrap's responsibility or an explicitly separate, documented second entry point. Do not default this silently.
4. Investigate OpenRouter's `/models` endpoint (`supported_parameters`) as the capability-filtering data source, since OpenRouter is the provider already configured in `.env` per project docs — versus hand-maintaining a capability table that will go stale.

## Explicitly out of scope for this card
- Any UI screen (future React frontend, separate from this gem).
- Wiring the registry into actual call sites (Pass 2, narrative, sprint roles) — that's follow-up cards once the schema is decided.

## Deliverable
A short design decision recorded on this track (`add_track_decision`) covering items 2 and 3 above, plus a Context7-confirmed `tty-config` usage sketch.