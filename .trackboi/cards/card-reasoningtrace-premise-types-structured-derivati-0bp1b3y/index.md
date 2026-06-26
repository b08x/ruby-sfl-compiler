---
id: "card-reasoningtrace-premise-types-structured-derivati-0bp1b3y"
boardId: "default"
title: "ReasoningTrace + Premise types — structured derivation for Pass 2 annotations"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-source-reasoning-layer-structured-reasoningtrace-0fzkzub"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T03:49:10.491Z"
updatedAt: "2026-06-26T03:51:08.570Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Structured ReasoningTrace replacing the opaque reasoning: String field on InterpersonalPayload. Premise → inference rule → conclusion → SHA256 derivation_hash computed in Ruby (never trusted from the LLM).

IMPLEMENTED:
- Types::Premise (Dry::Struct) — type, source, value, weight (types.rb line 169). Open taxonomy for evidence categories (not a fixed enum — verified against live Pass 2 run).
- Types::ReasoningTrace (Dry::Struct) — premises[], inference_rule, conclusion (Hash), confidence (0-1), derivation_hash (SHA256), generated_at (types.rb line 189).
- InterpersonalPayload gains reasoning_trace attribute (types.rb line 207, optional, defaults nil).
- PassTwoEngine bridge code computes derivation_hash from actual returned values, never trusts LLM-emitted hash.
- ReasoningVerifier (as CrabConstraintJob invariant) — still todo per the shared substrate track, not this card.
- Markdown/JSON formatters include reasoning_trace in serialized output.