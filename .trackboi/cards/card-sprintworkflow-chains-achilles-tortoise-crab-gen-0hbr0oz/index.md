---
id: "card-sprintworkflow-chains-achilles-tortoise-crab-gen-0hbr0oz"
boardId: "default"
title: "SprintWorkflow — chains Achilles → Tortoise → Crab → Genie"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:41:26.202Z"
updatedAt: "2026-06-25T02:29:39.254Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
`Gush::Workflow` subclass (`lib/sfl/compiler/workflows/sprint_workflow.rb`) that wires the four-role sequential chain, depends on the SprintRoleJob and CrabConstraintJob cards in this track (both shipped — commits 66a58d0, 4373d61).

```ruby
class SprintWorkflow < Gush::Workflow
  def configure(domain_payload)
    achilles = run SprintRoleJob, params: { role: :achilles, signature_class: domain_payload[:propose_signature],  lm: domain_payload[:achilles_lm], input: domain_payload[:input] }
    tortoise = run SprintRoleJob, params: { role: :tortoise, signature_class: domain_payload[:challenge_signature], lm: domain_payload[:tortoise_lm] }, after: [achilles]
    crab     = run CrabConstraintJob, params: { invariants: domain_payload[:invariants], claims_field: domain_payload[:claims_field] }, after: [tortoise]
    genie    = run SprintRoleJob, params: { role: :genie, signature_class: domain_payload[:synthesize_signature],  lm: domain_payload[:genie_lm] }, after: [crab]
  end
end
```

**Updated since the original draft**: `domain_payload[:invariants]` must be the JSON-safe data shape `CrabConstraintJob` actually implements — `[{name:, field:, op:, value:}, ...]` with `op` one of `eq/neq/gt/gte/lt/lte/present/absent` — NOT `{name:, check: ->(claim) {...}}` Procs as originally sketched (Procs can't survive `Gush::Job#to_json`'s Redis serialization when a job crosses a Sidekiq process boundary; see `CrabConstraintJob`'s file comment and card history). `domain_payload[:claims_field]` is optional, defaulting to `"claims"` in `CrabConstraintJob` — only needed if a domain signature names its claims list something else.

Sequential `after:` chaining verified against chaps-io/gush's `SimpleWorkflow` example (`run SaveJob, after: DownloadJob`). `domain_payload` is the *only* per-track customization point: signature classes, LM provider strings, invariants, and the seed input. No domain track needs to define its own Workflow class.

RSpec integration spec analogous to `spec/sfl/compiler/workflows/conversation_analysis_workflow_spec.rb` (real Redis, `ActiveJob::Base.queue_adapter = :inline`): a fixture `domain_payload` with stub DSPy signatures runs end-to-end through all four stages and produces a final Genie output that reflects Crab's filtering.

Acceptance: swapping `domain_payload` for a second fixture (different signature classes / invariants, same workflow class) produces a structurally identical run — proves no domain-specific code leaked into `SprintWorkflow` itself.