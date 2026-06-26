## Why this track exists

Three GEB-flavored tracks on this board (`narrative-generation-as-strange-loop-closure`, `documentation-deep-dive-with-constraint-pinning`, `cross-document-g-del-encoded-question-graph`) independently plan Achilles/Tortoise/Crab/Genie multi-agent sprints. The four-role *shape* is identical across all three — only the domain content (narrative claims vs. modality claims vs. cross-document questions) differs. Building it three times is the bug; this track is the fix.

## Design (POODR-informed, from the 2026-06-25 architecture-meeting brainstorm)

- Ch07 (role/module sharing): Achilles/Tortoise/Crab/Genie is a **role**, orthogonal to domain — not a class hierarchy per track.
- Ch08 (composition over inheritance): a Sprint *has-a* four pluggable role assignments, built from config, not baked into subclasses.

### Verified API (Context7, 2026-06-25)

- **Gush**: `run JobClass, params: {...}, after: [job_ids]` for sequential chaining; `payloads.find { |p| p[:class] == X }[:output]` for cross-job data — confirmed against the same API `CompileTurnJob`/`ReduceTurnsJob` already use.
- **DSPy.rb**: LM configuration is per-*instance*, not per-class — `module.configure { |c| c.lm = DSPy::LM.new(provider) }` overrides the global LM on just that object. This is what makes "Achilles uses model A, Tortoise uses model B" possible without four hardcoded subclasses.

### Two job shapes, not four

```
SprintWorkflow < Gush::Workflow
  configure(domain_payload)
    achilles = run SprintRoleJob, params: { role: :achilles, signature: domain_payload[:propose_signature],  lm: "..." }
    tortoise = run SprintRoleJob, params: { role: :tortoise, signature: domain_payload[:challenge_signature], lm: "..." }, after: [achilles]
    crab     = run CrabConstraintJob, params: { invariants: domain_payload[:invariants] },                    after: [tortoise]
    genie    = run SprintRoleJob, params: { role: :genie, signature: domain_payload[:synthesize_signature],   lm: "..." }, after: [crab]
```

- `SprintRoleJob` — one Gush::Job class for Achilles/Tortoise/Genie. `#perform` is a template method mirroring `CompileTurnJob`'s existing shape (Bootstrap inside `#perform`, build DSPy module named in `params`, configure its LM, forward, `output(...)`).
- `CrabConstraintJob` — separate, because Crab is rule-based invariant pinning, not an LM call; forcing it through the LM template method would violate SRP.
- Domain signature classes (`NarrativeClaimSignature`, etc.) are named in `params`, never subclassed into the job.

## Relationship to the other Gush workflow already shipped

`ConversationAnalysisWorkflow` (fan-out/fan-in over turns) and `SprintWorkflow` (sequential 4-stage pipeline) are different Gush shapes for different problems. They compose by sequencing: a finished `AnalysisResult`/report becomes a `SprintWorkflow`'s `domain_payload`, not a merge of the two workflow classes.

## Scope

Files: `lib/sfl/compiler/jobs/sprint_role_job.rb`, `lib/sfl/compiler/jobs/crab_constraint_job.rb`, `lib/sfl/compiler/workflows/sprint_workflow.rb`. Each of the three GEB tracks supplies its own DSPy::Signature classes + invariants config as a separate, much smaller card once this substrate exists.
