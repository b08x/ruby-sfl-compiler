## Why this track exists

`sfl-analyze narrate report.json` (and the `--narrative` flag on conversation/documentation) generates a markdown narrative from an analysis result. This IS a Hofstadter strange loop: the compiler analyzes text, then generates text *about its own analysis*. Currently this is a single-pass, single-model operation with no self-verification.

The GEB angle: the narrative generator (Achilles) proposes claims about tenor escalation, mood shifts, speaker dynamics. But who checks whether those claims are grounded in actual clause data? Who verifies the narrative generator isn't hallucinating stories from noisy annotations?

Crucially, this track requires **different LLM models** for generation vs. verification — using the same model for both commits the RLHF category error (treating social-contract alignment as parameter update: the model "agrees with itself" structurally).

## Multi-model requirement (enforced)

| Phase | Agent | Model strategy | Rationale |
|-------|-------|---------------|-----------|
| **Generation** | Achilles | `ruby_llm` with a fast/cheap model (e.g. Claude Haiku, GPT-4o-mini) | Produce narrative draft cost-effectively |
| **Skepticism** | Tortoise | Different model than generation | Challenge claims using a model with no stake in the draft |
| **Constraint** | Crab | Rule-based + any model for citation check | Every narrative claim MUST cite a clause_id; uncited = non-theorem |
| **Synthesis** | Genie | Same as generation OR a third model | Encode findings, decide if narrative passes or needs re-generation |

Anti-pattern: using one model for both generation and verification is like asking the Tortoise to critique the Achilles' essay in Achilles' own voice — it's a monologue, not a dialogue.

## GEB mapping (strange loop explicit)

The strange loop is REAL here, not metaphorical:
1. `sfl-analyze conversation chat.jsonl` → produces annotated clauses (Pass 1 + Pass 2)
2. `sfl-analyze narrate output/latest/report.json` → produces narrative_report.md
3. Run `sfl-analyze conversation output/latest/narrative_report.md` → the narrative's own tenor/mood/profile is analyzed
4. Compare: does the narrative's interpersonal profile match the source? A mismatch reveals the generator hallucinated structure (e.g., "escalating tension" in a conversation that was actually flat)

This is the compiler analyzing text about the compiler's own categories — a literal strange loop (GEB Ch XX).

## Pitfalls

- **RLHF category error**: using one model for gen+verify = asking the same parameter set to self-validate
- **Tortoise blocking by design**: Tortoise objections should be recorded but not veto the narrative — route to Genie for arbitration
- **Narrative "beauty" as quality metric**: aesthetic scoring of narrative prose (The Magnificrab principle) must NOT override factual grounding to cited clauses
