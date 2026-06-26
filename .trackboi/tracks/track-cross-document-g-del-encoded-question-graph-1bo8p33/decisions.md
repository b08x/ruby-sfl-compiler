# Decisions

## [accepted] SprintOrchestrator sits above SprintWorkflow — different layers, not a merge

During the 2026-06-25 architecture-meeting brainstorm, considered folding `SprintOrchestrator`'s halting/Gödel-encoding logic into the new shared `track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi`. Rejected: they answer different questions. `SprintOrchestrator` (this track) decides *whether to run another sprint at all* and *which questions go into it* (halting predicate, Gödel factorization across sessions) — it has no opinion on how a single sprint's four roles execute. `SprintWorkflow` (shared substrate) executes *one* sprint's Achilles→Tortoise→Crab→Genie chain via Gush — it has no opinion on cross-session state. The intended composition once both exist: `SprintOrchestrator#next_sprint_graph` produces a `QuestionGraph`, which gets turned into one `SprintWorkflow.create(domain_payload)` call per sprint iteration. Keep them as separate classes/tracks; do not merge.
