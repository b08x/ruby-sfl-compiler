---
id: "card-fix-cognitivegas-on-gas-exhausted-fires-with-wro-0rimlzw"
boardId: "default"
title: "Fix: CognitiveGas on_gas_exhausted fires with wrong-namespace clause ids (Rolling Synthesis always compresses zero clauses)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-cognitive-gas-semantic-circuit-breaker-0xefy41"
column: "backlog"
rank: "yyx"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T15:34:59.074Z"
updatedAt: "2026-07-03T15:34:59.074Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Confirmed live (2026-07-03, `experiments/repro_gas_exhaustion_bug.rb`, see `experiments/RESULTS.md` "Bug 1"): `PassTwoEngine#trigger_rolling_synthesis` fires `on_gas_exhausted` with `chunk.map { |e| e[:clause].id }` — `SyntacticClause#id`, assigned at Pass 1 (`pass_one_engine.rb:65`, `SecureRandom.uuid`). But `IntermediateGenieJob#perform` looks clauses up via `ClauseRepository#find(id)`, keyed on `clauses.external_id` — populated from `AnnotatedClause#id`, assigned independently by `PassTwoEngine#annotated_clause` (`pass_two_engine.rb:465`, a second unrelated `SecureRandom.uuid`). These are always different UUIDs for the same clause; the lookup always returns nil.

Live repro:
```
Pass-1 SyntacticClause ids: ["a5561825-...", "d5aec6e3-...", "6706e0c5-..."]
on_gas_exhausted fired with ids: ["a5561825-...", "d5aec6e3-...", "6706e0c5-..."]
AnnotatedClause ids (what actually lands in clauses.external_id): ["8abf2923-...", "219cd89a-...", "859a74d9-..."]
IDs match: false
IntermediateGenieJob output: {summary_text: "No evidence provided for analysis.", clause_count: 0, ...}
```

**Second, independent problem** even if IDs matched: `trigger_rolling_synthesis` fires for the chunk about to be Pass-2-annotated — before it's annotated OR stored anywhere. The semantically correct behavior ("compress what's been processed so far") needs `on_gas_exhausted` to receive already-completed, already-stored clause ids from *prior* chunks, not the incoming one. That requires threading a completed-results accumulator through `annotate_batch`'s (partly concurrent, via `parallel_map`) chunk loop — a real design change to `PassTwoEngine`, not a one-line id fix.

**Impact**: every real CognitiveGas-triggered Rolling Synthesis cycle would silently build a degenerate Axiomatic summary from zero clauses. Currently harmless only because nothing in `lib/` actually injects `CognitiveGas`/`on_gas_exhausted` into a production `PassTwoEngine` (per CLAUDE.md gotcha #2) — but blocks Rolling Synthesis from ever working once someone does wire it in.

**Acceptance**: `on_gas_exhausted` receives ids that resolve via `ClauseRepository#find` to real, already-stored clauses; `experiments/repro_gas_exhaustion_bug.rb` (or its spec equivalent) shows a non-degenerate summary.