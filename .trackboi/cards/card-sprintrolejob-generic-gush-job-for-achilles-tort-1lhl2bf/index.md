---
id: "card-sprintrolejob-generic-gush-job-for-achilles-tort-1lhl2bf"
boardId: "default"
title: "SprintRoleJob — generic Gush::Job for Achilles/Tortoise/Genie roles"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:41:12.681Z"
updatedAt: "2026-06-25T02:15:49.285Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
One `Gush::Job` subclass (`lib/sfl/compiler/jobs/sprint_role_job.rb`, flat-constant via Zeitwerk collapse like `compile_turn_job.rb`) used for the three LLM-backed sprint roles (Achilles=propose, Tortoise=challenge, Genie=synthesize).

`#perform` mirrors `CompileTurnJob`'s existing shape:
1. `Bootstrap.call(require_db: false, require_llm: false, ...)` (LM is configured per-instance below, not globally).
2. Build the `DSPy::Signature`/`ChainOfThought` named by `params[:signature_class]` (string constant lookup, like other dynamic-class params in this codebase).
3. `module.configure { |c| c.lm = DSPy::LM.new(params[:lm], api_key: ...) }` — verified via Context7 against vicentereig/dspy.rb: LM config is per-instance, this is how Achilles/Tortoise/Genie get different models without subclassing.
4. `forward(**params[:input])`, then `output(Types.dump(result))` (or equivalent JSON-safe hash).

RSpec: stub the DSPy module, assert `configure` received the right LM provider string per role, assert `output` is JSON-round-trippable. Reuse `spec/sfl/compiler/jobs/compile_turn_job_spec.rb`'s `job.payloads = [...]` pattern for any role that reads a prior role's output via `payloads`.

Acceptance: three `SprintRoleJob` instances with `role: :achilles/:tortoise/:genie` and three different `lm:` provider strings each call `DSPy::LM.new` with their own distinct argument — no shared global LM state leaks between them.