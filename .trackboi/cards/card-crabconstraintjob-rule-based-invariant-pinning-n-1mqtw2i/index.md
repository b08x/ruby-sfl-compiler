---
id: "card-crabconstraintjob-rule-based-invariant-pinning-n-1mqtw2i"
boardId: "default"
title: "CrabConstraintJob — rule-based invariant pinning, no LM call"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:41:19.583Z"
updatedAt: "2026-06-25T02:22:21.502Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
A second `Gush::Job` subclass (`lib/sfl/compiler/jobs/crab_constraint_job.rb`), deliberately separate from `SprintRoleJob` because Crab's role (pin invariants, reject claims that violate them) is rule-based business logic, not an LLM call — folding it into the LM template method would violate SRP.

`#perform`:
1. Reads the prior role's output via `payloads.find { |p| p[:class] == "SprintRoleJob" }[:output]` (Gush payload API, verified via Context7 against chaps-io/gush README).
2. Runs `params[:invariants]` — an array of `{name:, check: ->(claim) { ... }}`-shaped rules (or a simpler declarative form; decide at implementation time) against the prior role's claims.
3. Outputs `{ passed_claims:, rejected_claims:, violations: [...] }`.

Domain tracks supply `invariants:` as plain data/procs — e.g. documentation-deep-dive's "fallback clauses excluded from averages" or "minimum 30 clauses" rules — without needing their own job class.

RSpec: a claim violating a supplied invariant ends up in `rejected_claims` with the violation reason; a claim passing all invariants ends up in `passed_claims`; empty `invariants:` passes everything through unchanged.

Acceptance: running with the documentation track's two known invariants (fallback-exclusion, min-clause-threshold) against a fixture set of claims correctly partitions them — proves the generic shape fits a real domain's rules, not just a strawman.