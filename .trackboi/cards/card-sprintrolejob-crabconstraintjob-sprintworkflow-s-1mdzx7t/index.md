---
id: "card-sprintrolejob-crabconstraintjob-sprintworkflow-s-1mdzx7t"
boardId: "default"
title: "SprintRoleJob + CrabConstraintJob + SprintWorkflow — shared sprint-role substrate"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T03:48:49.040Z"
updatedAt: "2026-06-26T03:48:53.837Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Generic Gush-backed substrate for the Achilles/Tortoise/Crab/Genie role pattern: one parameterized SprintRoleJob for the three LLM roles, one CrabConstraintJob for rule-based invariant pinning, and one SprintWorkflow chaining them sequentially.

IMPLEMENTED:
- lib/sfl/compiler/jobs/sprint_role_job.rb — SprintRoleJob < Gush::Job, generic Achilles/Tortoise/Genie role runner with per-instance DSPy LM config
- lib/sfl/compiler/jobs/crab_constraint_job.rb — CrabConstraintJob < Gush::Job, rule-based invariant pinning (separate from LM roles per SRP)
- lib/sfl/compiler/workflows/sprint_workflow.rb — SprintWorkflow < Gush::Workflow, chains Achilles → Tortoise → Crab → Genie sequentially
- SprintWorkflow spec: runs end-to-end, produces Genie output reflecting Crab's filtering
- Domain tracks supply only a DSPy::Signature class + invariants config, not their own role-runner