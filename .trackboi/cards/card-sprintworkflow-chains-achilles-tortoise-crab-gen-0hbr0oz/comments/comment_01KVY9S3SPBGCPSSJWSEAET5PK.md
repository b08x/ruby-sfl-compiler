---
id: "comment_01KVY9S3SPBGCPSSJWSEAET5PK"
cardId: "card-sprintworkflow-chains-achilles-tortoise-crab-gen-0hbr0oz"
createdAt: "2026-06-25T02:29:39.254Z"
updatedAt: "2026-06-25T02:29:39.254Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in `lib/sfl/compiler/workflows/sprint_workflow.rb` (commit 4bc8cea). This card completes the shared-substrate track — all 3 cards now shipped.

**Two real bugs found and fixed by this card's integration spec** (real Redis + `:inline` ActiveJob adapter, same pattern as `conversation_analysis_workflow_spec.rb`) — neither was catchable by the prior two cards' unit specs, since those hand-built `payloads`/`params` fixtures instead of exercising a real Gush DAG:
1. `CrabConstraintJob` matched `payloads` against the bare class name `"SprintRoleJob"`, but `Gush::Worker#incoming_payloads` stores `job.klass.to_s` — the fully-qualified `"SFL::Compiler::SprintRoleJob"`. Lookup always returned nil for a real job. Fixed to `SprintRoleJob.to_s`.
2. `SprintWorkflow` passed `claims_field: domain_payload[:claims_field]` unconditionally — setting the params key to an explicit `nil` when absent, which defeats `CrabConstraintJob`'s own `params.fetch(:claims_field, "claims")` default (`#fetch`'s default only applies when the key is *absent*, not when present-with-nil-value). Fixed to `domain_payload.fetch(:claims_field, "claims")`.

**Also extended the already-shipped `SprintRoleJob`** (this track's 3rd card) to merge a direct dependency's output into its DSPy input under `prior_output_key` — the original card never specified how Tortoise sees Achilles' draft or Genie sees Crab's filtered claims; without this, the chain would run but each stage would be blind to the previous one's actual content.

2 new integration specs (full 4-stage run + a second domain_payload proving no domain-specific code leaked into the shared class), plus 1 new spec on the amended `SprintRoleJob`. Full suite: 339 examples, 0 failures.

This closes out `track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi`. The narrative track's multi-model card is the first real consumer of this substrate.