---
id: "card-multi-model-narrative-generation-with-model-iden-17t19wu"
boardId: "default"
title: "Multi-model narrative generation with model identity enforcement"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-narrative-generation-as-strange-loop-closure-0r3gaye"
column: "done"
rank: "yy"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:23:08.088Z"
updatedAt: "2026-07-02T18:59:06.028Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Multi-model narrative generation with model identity enforcement — **now built on the shared sprint-role substrate** (`track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi`) rather than a bespoke gen/verify loop inside `NarrativeGenerator`. Original draft of this card hand-rolled `generation_model:`/`verification_model:` params directly on `NarrativeGenerator`; that duplicated the Achilles/Genie role shape the shared substrate now provides generically. Superseded by composing `SprintWorkflow` instead.

Requirements (revised):
1. Define `NarrativeProposeSignature` (Achilles — drafts the narrative from source clauses) and `NarrativeVerifySignature` (Genie — reads draft + source clauses, returns `{ grounded_claims:, ungrounded_claims:, citation_coverage: Float }`). These are the only new domain-specific artifacts this card owns.
2. Define the Tortoise challenge signature (skeptical re-read of the draft before Genie verifies) and a Crab invariant: `citation_coverage < 0.8` → reject, route back to Achilles for re-generation (max 2 attempts — same cap as the original draft's requirement 4).
3. `Analysis::NarrativeGenerator` (or `sfl-analyze narrate`) builds a `domain_payload` (propose/challenge/synthesize signatures + `achilles_lm`/`tortoise_lm`/`genie_lm` strings + invariants) and hands it to `SprintWorkflow.create(domain_payload)` — it does NOT implement its own model-conflict checking or re-generation loop; that's `SprintRoleJob`/`CrabConstraintJob`/`SprintWorkflow`'s job now.
4. `achilles_lm` and `genie_lm` (generation vs. verification) MUST differ — raise before `SprintWorkflow.create` if they're identical (still need this guard; it's the actual RLHF-category-error prevention, just enforced at the call site rather than inside `NarrativeGenerator`).
5. RSpec tests: (a) identical achilles/genie LM raises before workflow creation, (b) workflow run with the three real signature classes + low-citation-coverage fixture re-routes through Crab back to Achilles, (c) max-2-attempts then best-effort with a warning flag surfaces in the final report.

Acceptance: `sfl-analyze narrate report.json --generation-model claude-haiku --verification-model claude-sonnet` produces a narrative with a verification footer showing citation coverage, by running `SprintWorkflow` under the hood — not a separate code path. Using the same model for both flags raises before any Gush job is enqueued.

Depends on: `card-sprintrolejob-generic-gush-job-for-achilles-tort-1lhl2bf`, `card-crabconstraintjob-rule-based-invariant-pinning-n-1mqtw2i`, `card-sprintworkflow-chains-achilles-tortoise-crab-gen-0hbr0oz`.