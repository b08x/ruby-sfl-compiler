---
id: "comment_01KWJ35W5CXC5BRN1TM4J6AE3X"
cardId: "card-multi-model-narrative-generation-with-model-iden-17t19wu"
createdAt: "2026-07-02T18:59:06.028Z"
updatedAt: "2026-07-02T18:59:06.028Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done — implemented as synchronous inline loop (not SprintWorkflow)**

Card description called for `SprintWorkflow` as the substrate, but SprintWorkflow is a linear A→T→C→G pipeline with no loop-back mechanism. The citation-coverage retry loop (max 2 attempts) is inherently iterative, not a one-shot DAG, so implemented as `MultiModelNarrator#call` — same synchronous pattern as `SFLNarrator`.

**What shipped:**
- `NarrativeProposeSignature` (Achilles), `NarrativeChallengeSignature` (Tortoise), `NarrativeVerifySignature` (Genie) in `narrative_generator.rb`
- `MultiModelNarrator` class: raises `ArgumentError` when `generation_model == verification_model`; retries up to `MAX_ATTEMPTS=2` when `citation_coverage < CITATION_THRESHOLD=0.8`; best-effort fallback appends low-coverage warning to `data_quality`
- `--generation-model`/`--verification-model` CLI flags on `sfl-analyze narrate`; validates both set or both omitted
- 5 new RSpec examples, all green

**Test result:** 548 examples, 0 failures.