## Why this track exists

The sfl-compiler has no mechanism for tracking research questions across runs. Each `sfl-analyze` invocation is stateless — the pipeline doesn't know what it asked before, what was deferred, or which questions depended on prior answers. This means:

1. Re-running with different parameters repeats work already done
2. Cross-document questions ("Does this finding hold across document types?") are never explicitly tracked
3. There's no structured way to decide "we need to run Sprint N+1" or "this question is Gödel-type unresolvable"

## GEB mapping: full multi-agent sprint pipeline

The QuestionGraph class (from `hofstadter-geb-ai-ruby` skill, `references/multi-agent-sprint-orchestration.md`) encodes question-dependency DAGs as a single Gödel number via prime factorization.

```
Sprint N:
  Achilles: Propose discovery questions ("Does formal docs have higher modality?")
  Tortoise: Challenge assumptions ("Define formal. Is it doc type or language?")
  Crab: Pin axioms + invariants ("formal = API reference", minimum 30 clauses)
  Genie: Encode results as Gödel number G_N, identify deferred questions

Sprint N+1:
  New agent factors G_N → discovers unresolved derived questions
  Spawns child cards for follow-up
  Re-runs with expanded scope
  Merges into G_{N+1}
```

## Encoding scheme (seed-prime corrected)

Axiomatic question = next prime (2, 3, 5...)
Derived question = next seed prime × product(dependency primes)
Gödel number = product of all question primes

Factorization recovers the full DAG. No metadata needed.

## Components to build

1. **`lib/sfl/compiler/question_graph.rb`** — Gödel-encoded QuestionGraph class with encode/factor/decode/consistent? methods
2. **`lib/sfl/compiler/sprint_orchestrator.rb`** — Manages sprint state, halting predicate (RQ stable OR budget exhausted), Gödel encoding between sessions
3. **Sprint report footer** — `Sprint N | G_N = <number>` in narrative_report.md so future runs can factor it
4. **CLI: `sfl-analyze sprint`** (optional, or extend existing commands with `--sprint-id`) — resume/query existing sprint

## Known constraints / decisions

- Halting predicate must be concrete: "RQ no longer changes" AND "token budget < 80% consumed" (RQ stable at wrong answer is failure, not success)
- Gödel number stored as BigInt in database or as string in report footer (bignum support needed)
- Child sprints use `parents` in kanban for dependency tracking — question_graph.encode cross-links via Gödel seed primes

## Goal

A sprint system where each analysis run knows what it asked before, encodes findings compactly, and can resume across sessions with full question-graph recovery. The Genie writes G_N in the report; Sprint N+1 factors it and knows exactly which questions existed and which were deferred.
