---
id: "comment_01KW126F4Q11CM0SBGC98HYV5R"
cardId: "card-design-model-provider-config-schema-verify-tty-c-1lds93z"
createdAt: "2026-06-26T04:14:51.543Z"
updatedAt: "2026-06-26T04:14:51.543Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Priority elevated — Phase 2 prerequisite (2026-06-26):** Multi-model workflows are now load-bearing for multiple Phase 2 tracks. `SprintWorkflow` already enforces `achilles_lm != genie_lm` (raises before workflow creation if identical). Rolling Synthesis's intermediate Genie needs its own LM config. Cognitive Gas cost weights may vary by model capability. The Falcon API needs per-endpoint model routing. User note still applies: evaluate RubyLLM model catalog (https://rubyllm.com/available-models/) as the source of truth for available models and capability filtering — prefer it over hardcoding provider strings or querying OpenRouter's `/models` endpoint directly.