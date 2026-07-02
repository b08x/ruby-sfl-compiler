---
id: "comment_01KWJ5ZVVVZJ1A2JT6RZ62MP82"
cardId: "card-implement-cognitivegas-and-inject-into-passtwoen-1qwk9v6"
createdAt: "2026-07-02T19:48:14.843Z"
updatedAt: "2026-07-02T19:48:14.843Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in commit 72ff9e4.

Cost function (Pass 1 data only — available before LLM call):
- `PROCESS_COSTS`: material/mental=3, verbal/behavioral=2, relational/existential=1
- + token count (capped at 20) + participant count
- Accepts both `{ clause:, ideational: }` Hash and `[clause, ideational]` pair forms

Integration: `annotate_chunk` calls `@circuit_breaker.charge_batch(chunk)` before building `items` if breaker responds to `:charge_batch`. Backward compatible — `CircuitBreaker::CircuitHandler` ignores the duck-typed call.

Card 3 (graceful summarization → Rolling Synthesis trigger) deferred: depends on IntermediateGenieJob being implemented first.