---
id: "card-fix-openrouter-google-fallback-provider-parsing--0itazxv"
boardId: "default"
title: "Fix \"openrouter/google/...\" fallback provider parsing (DSPy::LM::UnsupportedProviderError)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: null
column: "backlog"
rank: "yyr"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T10:08:40.521Z"
updatedAt: "2026-07-03T10:08:40.521Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Found incidentally while resolving the Bootstrap::BootstrapError card (2026-07-03), by deliberately reverting that fix and re-running to isolate what it did and didn't explain. With the constant bug fixed, `circuit_breaker_spec.rb --seed 2` in full-suite context still has 3 failures — all `DSPy::LM::UnsupportedProviderError: Unsupported provider: google. Available: openai, anthropic, ollama, gemini, openrouter, ruby_llm`.

Root: `.env`'s `SFL_FALLBACK_PROVIDERS` includes `openrouter/google/gemini-2.5-flash-lite` — a three-segment OpenRouter model path (`openrouter/<vendor>/<model>`). Somewhere in `ProviderFallback.build_chain`/`build_lm` (`lib/sfl/compiler/pass_two/provider_fallback.rb`, stack trace bottoms out at line 96's `DSPy::LM.new(provider, ...)`), the provider string handed to `DSPy::LM.new` ends up being (or resolving to) `"google"` alone rather than `"openrouter/google/gemini-2.5-flash-lite"` or however DSPy::LM expects a vendor-qualified OpenRouter model to be passed. DSPy::LM's adapter factory only recognizes top-level provider prefixes (`openai, anthropic, ollama, gemini, openrouter, ruby_llm`) — "google" isn't one of them (the OpenRouter-hosted Google models use vendor path `google/...` *within* the `openrouter/` prefix, not as a top-level DSPy provider).

Only reproduces with certain RSpec seeds because it depends on `SFL_FALLBACK_PROVIDERS` array position combined with which spec/test happens to construct a full fallback chain including this entry — not spec-file-order-independent, so likely present any time this env var's fallback chain gets built with an unmocked/real construction path.

Acceptance: `circuit_breaker_spec.rb --seed 2` passes in full-suite context (`bundle exec rspec spec/ --exclude-pattern "integration/**/*" --seed 2`).