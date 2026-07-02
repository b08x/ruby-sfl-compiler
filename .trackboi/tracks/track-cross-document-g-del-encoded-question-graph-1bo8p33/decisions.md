# Decisions

## [accepted] SprintOrchestrator sits above SprintWorkflow — different layers, not a merge

During the 2026-06-25 architecture-meeting brainstorm, considered folding `SprintOrchestrator`'s halting/Gödel-encoding logic into the new shared `track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi`. Rejected: they answer different questions. `SprintOrchestrator` (this track) decides *whether to run another sprint at all* and *which questions go into it* (halting predicate, Gödel factorization across sessions) — it has no opinion on how a single sprint's four roles execute. `SprintWorkflow` (shared substrate) executes *one* sprint's Achilles→Tortoise→Crab→Genie chain via Gush — it has no opinion on cross-session state. The intended composition once both exist: `SprintOrchestrator#next_sprint_graph` produces a `QuestionGraph`, which gets turned into one `SprintWorkflow.create(domain_payload)` call per sprint iteration. Keep them as separate classes/tracks; do not merge.

## [accepted] Gödel encoding retired — replaced by adjacency-list QuestionGraph

The prime-factorization approach was mathematically elegant but overflowed BIGINT at ~6-7 nodes, gave no readable API for graph queries, and confused the mental model (it presented as a "question graph" but exposed no graph methods). 

Replaced in commit 52298bc with a standard two-list adjacency graph: `@children` (forward edges) and `@parents` (reverse/dependency edges). Public API: `roots`, `leaves`, `parents(id)`, `children(id)`, `ancestors(id)`, `descendants(id)`, `reachable?(from:, to:)`, `depth(id)`, `topological_order`.

Kahn's algorithm retained for topological sort. `sprint_metadata` now stores `sprint_roots`/`sprint_leaves` instead of `sprint_godel_number`. All `gödel_number`, `factor`, `decode`, `consistent?` methods removed. DB migration (`question_edges` table) still pending — see card `card-db-migration-question-edges-adjacency-list-repla-00bgpag`.
