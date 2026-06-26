---
id: "comment_01KVYKWJVPPA2GFQGGQNXA8472"
cardId: "card-fix-batch-pass-2-premises-field-fails-sorbet-coe-0y7iz8l"
createdAt: "2026-06-25T05:26:18.742Z"
updatedAt: "2026-06-25T05:26:18.742Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Done — commit 1df1437.

**Important correction to this card's own root-cause draft**: live reproduction did NOT confirm the Sorbet nested-struct-array coercion theory. I ran `SFLBatchAnnotator.new(items).call` against the real configured LM (the `.env` provider, an OpenRouter auto-router alias "owl-alpha") repeatedly:
- 12-clause batch (the real default `SFL_BATCH_SIZE`), 5 attempts → 1 failure, but `DSPy::LM::AdapterError: unexpected end of input at line 164 column 1` — a **truncated/incomplete JSON response**, not a Sorbet `TypeError`.
- 6-clause batch, 8 attempts → 1 failure, `unexpected end of input at line 240` — a *later* line offset despite a *smaller* batch.

That second result rules out the "shrink the batch to fit a token budget" fix this card proposed as a candidate — failure isn't correlated with payload size, so it's not the `premises` schema specifically causing this; it's general provider-side flakiness in returning complete structured output. The exact Sorbet `TypeError` from the original photo is a different downstream symptom of the same underlying class of problem (incomplete/malformed LLM JSON), not independently reproduced — both are caught by the same rescue path either way.

**Actual fix**: `annotate_chunk` previously made exactly 2 attempts (1 retry, two separate `@circuit_breaker.call` invocations). At ~15-20% independent failure probability, 2 attempts still fails a chunk ~2-4% of the time — across hundreds of chunks in a 292-turn run, that's the repeated-`[WARN]`-stderr-flood pattern from the photo. Raised to `DEFAULT_BATCH_ATTEMPTS = 3` (`SFL_BATCH_ATTEMPTS` env override), refactored so all attempts happen inside **one** `@circuit_breaker.call` (new `call_annotator_with_retries`) — the circuit breaker's failure count now records one outcome per chunk, not one per internal attempt, so it doesn't trip 2-3x faster than before for the same real failure rate.

Verified: 2 new specs (exhausted-attempts fallback, custom `batch_attempts`), full suite 372/0, rubocop diff confirms zero new offenses (same pre-existing Metrics set, shifted line numbers only), live `sfl-analyze conversation` run against the sample fixture — 5/5 turns OK.