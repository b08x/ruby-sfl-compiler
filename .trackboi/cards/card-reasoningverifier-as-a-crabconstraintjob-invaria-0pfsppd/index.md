---
id: "card-reasoningverifier-as-a-crabconstraintjob-invaria-0pfsppd"
boardId: "default"
title: "ReasoningVerifier as a CrabConstraintJob invariant (not a new service)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-source-reasoning-layer-structured-reasoningtrace-0fzkzub"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:46:43.994Z"
updatedAt: "2026-06-25T02:40:22.011Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Independent re-derivation + divergence flagging is rule-based (recompute `compute_derivation_hash` from a `Types::ReasoningTrace`'s own `premises`/`inference_rule`/`conclusion`, compare to its stored `derivation_hash`) — exactly the shape `CrabConstraintJob` (`card-crabconstraintjob-rule-based-invariant-pinning-n-1mqtw2i`, `track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi`) already defines: `params[:invariants]` as declarative rules run against prior output, partitioning into `passed_claims`/`rejected_claims`.

Do NOT build a standalone `ReasoningVerifier` class. Instead, once `CrabConstraintJob` exists, supply one invariant:

```ruby
{
  name: "derivation_hash_reproducible",
  check: ->(trace) { compute_derivation_hash(trace.premises, trace.inference_rule, trace.conclusion) == trace.derivation_hash }
}
```

A mismatch means the stored hash doesn't match its own premises — either tampered, or (more likely in practice) the trace was built before a `compute_derivation_hash` algorithm change, which itself is useful signal: it flags every annotation whose provenance can't be re-verified under the current hashing rule.

Depends on: `card-crabconstraintjob-rule-based-invariant-pinning-n-1mqtw2i` shipping first. This card is just "register one invariant," not new infrastructure — keep it that small when implementing.

RSpec: a `ReasoningTrace` with a hand-corrupted `derivation_hash` (premises don't match) ends up in `rejected_claims` via this invariant; an untouched trace passes.

Acceptance: running `CrabConstraintJob` with this single invariant against a batch of real `ReasoningTrace`s from a live Pass 2 run correctly separates reproducible from non-reproducible ones.