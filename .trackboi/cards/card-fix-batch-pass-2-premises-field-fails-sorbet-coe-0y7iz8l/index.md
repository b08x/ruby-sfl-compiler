---
id: "card-fix-batch-pass-2-premises-field-fails-sorbet-coe-0y7iz8l"
boardId: "default"
title: "Fix: batch Pass 2 premises field fails Sorbet coercion on fresh (non-cached) LLM calls, flooding stderr"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-source-reasoning-layer-structured-reasoningtrace-0fzkzub"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T04:34:44.941Z"
updatedAt: "2026-06-25T05:26:18.742Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
## Symptom
`bundle exec sfl-analyze conversation <file> --topics 10 --narrative --resume` against a real 292-turn SillyTavern export appeared to "hard lock up" the workstation. User captured a photo of the terminal mid-incident.

## What the photo actually showed
Not a deadlock — a wall of rapidly repeating `[OK]`/`[WARN]` lines, breaking right around turn 120/299, followed by:

> "The LLM returned a plain Ruby array with hash elements, but your signature requires an array of SFL::Compiler::ClauseAnnotation struct objects." (DSPy::ErrorFormatter, `dspy-1.0.1/lib/dspy/error_formatter.rb:133`)

## Root cause
`ClauseAnnotation#premises` (`lib/sfl/compiler/pass_two/pass_two_engine.rb:613`) is `T::Array[PremiseOutput]` nested *inside* `SFLBatchSignature`'s own `annotations: T::Array[ClauseAnnotation]` — a struct-array nested two levels deep. Against the real configured provider, DSPy 1.0.1's structured-output deserialization fails to coerce the inner `premises` array into `PremiseOutput` structs, raising a Sorbet TypeError on every batch call that includes premises content.

`--resume` masked this for the first ~119 turns: they hit `.sfl-cache/` populated by a prior run *before* the `premises` field existed (added this session, Card #2 of the Source Reasoning Layer track), so cache hits skipped Pass 2 entirely. Turn 120 was the first turn requiring a fresh Pass 2 call — exactly where the failures start in the photo.

## Why it looked like a lockup, not a clean failure
`annotate_chunk`'s rescue ladder (`pass_two_engine.rb:208-244`) already catches this, retries once, then defaults the chunk — bounded, not infinite. But each failure logs DSPy's full multi-paragraph `ErrorFormatter` message via `[WARN]`, repeated per chunk, per retry, across `SFL_CONCURRENCY` (default 4) concurrent threads, for every remaining turn (~180 of them). The resulting stderr volume was enough to make the terminal/session appear frozen even though the process was making bounded (if degraded-to-defaults) progress.

## Next step (not yet done)
Reproduce in isolation: a small script calling `SFLBatchAnnotator.new(items).call` against the real configured LM with `premises` populated, to confirm whether this is a provider JSON-schema depth/strictness limitation (e.g. OpenRouter rejecting/flattening doubly-nested arrays-of-objects) before picking a fix. Candidate fixes once confirmed:
- Flatten `premises` serialization (e.g. JSON-string field instead of nested struct array) for the *batch* signature specifically (single-clause `SFLSignature` may not have the same problem — verify).
- Or pin/patch the coercion path if it's a DSPy bug specific to doubly-nested struct arrays.

## Acceptance criteria
- Root cause confirmed via reproduction script (not just static reading).
- Fix verified with a live `sfl-analyze conversation` run against the same fixture, including a forced-fresh (non-cached) run, with zero Sorbet TypeErrors in stderr.
- Existing rescue/default ladder behavior preserved for genuinely unrelated failures (don't swallow this fix by leaning on the existing fallback path — it should not fire at all once fixed).