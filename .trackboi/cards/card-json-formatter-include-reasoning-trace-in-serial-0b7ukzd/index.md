---
id: "card-json-formatter-include-reasoning-trace-in-serial-0b7ukzd"
boardId: "default"
title: "JSON formatter: include reasoning_trace in serialized output"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-source-reasoning-layer-structured-reasoningtrace-0fzkzub"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:46:53.341Z"
updatedAt: "2026-06-25T04:42:56.985Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
`lib/sfl/compiler/formatters/json_formatter.rb`: include `reasoning_trace` (or `nil`) in each clause's serialized hash, using the same `Types.dump`-style `deep_stringify_time` conversion already used for Gush JSON round-tripping (`generated_at` is a `::Time`, needs `.iso8601` on the way out — reuse `Types.deep_stringify_time`, don't hand-roll a second time-serialization path).

RSpec: serialize a clause with a populated `reasoning_trace`, assert the JSON round-trips `generated_at` as an ISO8601 string and `premises` as an array of plain hashes (not raising on `Premise`/`ReasoningTrace` not being directly JSON-serializable).

Acceptance: `conversation_analysis.json`'s clause entries include a `reasoning_trace` key matching the documented schema (`metadata.annotation_coverage` doc in the JSON formatter spec) for llm-sourced clauses, `null` for fallback/stub.