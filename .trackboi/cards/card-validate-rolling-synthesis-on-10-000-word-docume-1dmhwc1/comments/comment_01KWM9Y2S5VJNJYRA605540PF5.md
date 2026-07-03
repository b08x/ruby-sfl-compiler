---
id: "comment_01KWM9Y2S5VJNJYRA605540PF5"
cardId: "card-validate-rolling-synthesis-on-10-000-word-docume-1dmhwc1"
createdAt: "2026-07-03T15:35:39.557Z"
updatedAt: "2026-07-03T15:35:39.557Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done.** Full writeup in `experiments/RESULTS.md` (sfl-compiler `03816fa`). Ran a real ~7,434-word PDF (Bavali & Sadighi, "Chomsky's UG and Halliday's SFL", via `PdfLoader`/Kreuzberg) through Pass 1 + Pass 2 + `IntermediateGenieJob` compression, against real Postgres and a real DSPy/OpenRouter LLM — 79 clauses compiled, compressed into 6 fixed-15-clause Axiomatic summary windows.

**(1) Process type distribution preserved through compression** — ✅ PASS, 0.0pp delta (exact; the aggregate is computed deterministically from source rows, not LLM prose).

**(2) Stance filter hit-rate equivalence, raw clauses vs. summarized windows** — ❌ FAIL, 13–26 percentage-point deltas across several `min_modality`/`min_tenor` thresholds. Structural, not noise: averaging tenor/modality across a 15-clause window changes which side of a threshold the *aggregate* falls on vs. individual clauses. **Stance-filtered retrieval over Axiomatic summaries is not a safe substitute for filtering raw clauses** — worth a documented caveat or a design change if summaries are ever meant to back filtered retrieval, not just context-budget compression.

**(3) Context window stays bounded, not proportional to document length** — ✅ PASS, fixed at 15 clauses/call regardless of document position (by construction — `format_evidence` only ever sees its own window).

**Two production bugs surfaced along the way, more consequential than the three questions above** — both filed as follow-up cards rather than fixed here (both need real design decisions, not one-line patches):
- `card-fix-cognitivegas-on-gas-exhausted-fires-with-wro-0rimlzw` — CognitiveGas's `on_gas_exhausted` fires with Pass-1 `SyntacticClause` ids, but `IntermediateGenieJob` looks up `AnnotatedClause` ids (a completely different, independently-generated UUID) — every real gas-exhaustion cycle would build a summary from zero clauses, silently. Confirmed via `experiments/repro_gas_exhaustion_bug.rb`.
- `card-investigate-dspy-openrouter-llm-calls-hang-indef-0kj0scl` — DSPy/OpenRouter calls hung indefinitely past every configured timeout (chunk_timeout×batch_attempts ≈ 360s worst case; actual hangs ran 630s+ with zero recovery), confirmed via `CLOSE-WAIT`/`ESTABLISHED` sockets with large unread `Recv-Q` buffers. Worked around here via OS-process `timeout` isolation per section/window; only 26/59 sections completed within a 60s budget on the affected run — a high hang rate, not an edge case.

773 sfl-compiler examples still green (experiment scripts have no specs, consistent with the established `experiments/` convention).