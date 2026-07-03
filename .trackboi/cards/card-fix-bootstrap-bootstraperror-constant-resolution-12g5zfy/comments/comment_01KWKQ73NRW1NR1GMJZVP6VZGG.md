---
id: "comment_01KWKQ73NRW1NR1GMJZVP6VZGG"
cardId: "card-fix-bootstrap-bootstraperror-constant-resolution-12g5zfy"
createdAt: "2026-07-03T10:08:32.440Z"
updatedAt: "2026-07-03T10:08:32.440Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Fixed.** One-line change: `rescue Bootstrap::BootstrapError` → `rescue BootstrapError` in `provider_fallback.rb:42`. `ProviderFallback` is nested under `SFL::Compiler`, so bare `BootstrapError` resolves correctly through lexical scope — no full qualification needed.

**Acceptance criteria met**: `circuit_breaker_spec.rb --seed 7633` and `--seed 2` both pass, isolated (19/19 each) and in full-suite context (seed 7633: 734/0 clean).

**Verified the fix's actual effect**, not just its presence — temporarily reverted it and re-ran `--seed 2` on the full suite: with the original bug, 19 failures in `circuit_breaker_spec.rb` (the NameError cascades broadly once one test triggers it, poisoning subsequent tests in the same file/seed ordering). With the fix, only 3 remain.

**Those 3 are a distinct, separate, pre-existing bug** — surfaced by fixing this one, not caused by it: `DSPy::LM::UnsupportedProviderError: Unsupported provider: google`, originating from `.env`'s `SFL_FALLBACK_PROVIDERS=...,openrouter/google/gemini-2.5-flash-lite,...`. Something in `ProviderFallback.build_lm`'s provider-string parsing treats the middle segment ("google") as the provider prefix instead of the full `openrouter/google/gemini-2.5-flash-lite` being handled as an OpenRouter model path. Filed as its own card rather than folded in here, since it's a genuinely different failure class (provider-string parsing vs. constant resolution) and this card's stated scope/acceptance criteria are now fully satisfied.