---
id: "comment_01KVYB1FEY6ZFZD8QYPBH5DY2S"
cardId: "card-markdown-formatter-render-reasoning-traces-as-co-0v016d1"
createdAt: "2026-06-25T02:51:41.918Z"
updatedAt: "2026-06-25T02:51:41.918Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in `lib/sfl/compiler/formatters/markdown_formatter.rb` (commit 84ed9a1). The card assumed a "per-clause detail rendering" section already existed to attach to — it doesn't; this formatter is purely aggregate (speaker profiles, correlations, insights). Added a new `### 🔍 Reasoning Traces` section, same pattern as the existing `key_moments_section`/`example_passages_section`, listing every clause with a non-nil `reasoning_trace`.

**Ran the card's own acceptance criterion for real** (`sfl-analyze conversation` against the sample fixture, real LLM via OpenRouter) instead of stopping at unit specs, and it caught two real bugs immediately:
1. `Types::Premise#type`'s 7-value enum (guessed in an earlier card) didn't match real model output at all — live responses used `discourse_marker`, `modal_adjunct`, `auxiliary_inversion`, etc. Every single clause in the first live run hit the enum violation. Fixed by opening it to a plain `Types::String`.
2. **More serious**: that violation wasn't contained — `reasoning_trace_from` ran inside `#interpersonal_from`'s own rescue, so the Dry::Struct::Error defaulted the clause's mood/tenor/modality too, not just the reasoning trace. 100% of clauses in the live run were fallback-defaulted, even though the LLM's actual interpersonal annotation was fine. Added `#safe_reasoning_trace_from` as an isolated rescue boundary: a broken reasoning trace now only ever nils `reasoning_trace` itself, never the surrounding annotation.

Second live run after the fix: 5/5 turns `[OK]`, zero defaults, and the generated markdown report shows real `<details>` blocks with real premises and confidence values per clause — visually confirmed, not just asserted in a test. Full suite: 355 examples, 0 failures.

This is exactly the kind of bug live-running surfaces that mocked unit specs can't — both fixes apply retroactively to the already-shipped `Bridge` card too.