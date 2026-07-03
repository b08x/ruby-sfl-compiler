---
id: "comment_01KWKRJAGRDT4C27QS3KE621WV"
cardId: "card-fix-openrouter-google-fallback-provider-parsing--0itazxv"
createdAt: "2026-07-03T10:32:08.472Z"
updatedAt: "2026-07-03T10:32:08.472Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Diagnosis was wrong — corrected and resolved.**

Reproduced live before trusting this card's write-up: `ProviderFallback.build_chain` handles the three-segment `openrouter/google/gemini-2.5-flash-lite` path fine — `DSPy::LM.new`'s own `parse_model_id` does `split('/', 2)`, so provider correctly resolves to `"openrouter"` regardless of how many segments follow.

Actual root cause: `Bootstrap.call` (`lib/sfl/compiler/bootstrap.rb:71`) assigns `config.dspy_provider = env["DSPY_PROVIDER"]` *before* `configure_llm` can raise. `bootstrap_spec.rb`'s "raises BootstrapError when the provider's key is empty" example calls `Bootstrap.call` with `DSPY_PROVIDER=google/gemini-2.0-flash` (a real fixture in that spec, unrelated to `SFL_FALLBACK_PROVIDERS`) — the raise happens, but not before the mutation lands on the `SFL::Compiler.config` **singleton**, which nothing in that spec file ever restored. Any later spec in the same process relying on the default provider (`PassTwoEngine.new` without an explicit `provider:`, e.g. `circuit_breaker_spec.rb`) inherited the poisoned 2-segment `"google/gemini-2.0-flash"` string and failed with `DSPy::LM::UnsupportedProviderError: Unsupported provider: google` — a classic test-order-dependent global-state leak, not a provider-parsing bug at all.

Fix: `spec/sfl/compiler/bootstrap_spec.rb` now has an `around` hook that snapshots/restores `SFL::Compiler.config` per example. Verified 0 failures across seeds 1, 2, 7633, 42 (734 examples each). Committed as `099ca47`.

Moving to done; no fix needed in `provider_fallback.rb` or `AdapterFactory` — closing as invalid diagnosis, not deferred.