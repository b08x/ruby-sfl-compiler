# Decisions

## [accepted] Build multi-model narrative gen/verify on SprintWorkflow, not a bespoke loop

The multi-model narrative generation card originally planned its own `generation_model:`/`verification_model:` params and re-generation loop inside `Analysis::NarrativeGenerator`. That's structurally identical to the generic Achilles(propose)/Tortoise(challenge)/Crab(citation-coverage invariant)/Genie(verify+route) shape now built once in `track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi`. Decided to retarget the card onto `SprintWorkflow` and contribute only the narrative-specific DSPy::Signature classes + invariants, rather than maintain a second implementation of the same role pipeline. See that track's brief for the verified Gush/DSPy.rb API this relies on.
