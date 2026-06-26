---
id: "comment_01KVYJ1F15RG53S1TJJ8M58DN3"
cardId: "card-questiongraph-class-with-g-del-encoded-dag-073a9lw"
createdAt: "2026-06-25T04:54:01.509Z"
updatedAt: "2026-06-25T04:54:01.509Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Done — commit f67774c.

**Implementation note / scope clarification on `#decode`/`#consistent?`**: implemented as a self-consistency check on the *encoding* (every question's own value divides the gödel_number, which holds trivially since it's a multiplicative factor of that product), not blind dependency-edge recovery from an arbitrary integer with no other context. The card's spec doesn't define how edges would be recovered from exponents alone, so I scoped this honestly rather than overclaiming "full DAG recovery" — it does correctly satisfy the literal acceptance test (encode → factor → decode recovers the original id set) for all three required cases: 5-question graph, single-question graph, and a 3-deep nested chain resolved via topological sort (Kahn's algorithm) so input order doesn't matter.

**Design**: one shared prime sequence (not "axiom primes then a separate derived-seed sequence") — every question, axiomatic or derived, consumes the next prime in topological order. Axiomatic questions use it directly; derived questions multiply it by the product of their dependencies' values. This matches the card's two examples (13×2=26 for a single dependency, 17×6=102 for two) once axioms have consumed the first several primes.

Added `prime` as an explicit gemspec dependency — it's a bundled (not default) gem as of Ruby 3.1+, caused a `LoadError` until added.

Verified: 13 new specs covering all 3 required edge cases + cycle/missing-dependency error cases, full suite 370 examples/0 failures, rubocop clean on the new lib file (added `# rubocop:disable Naming/AsciiIdentifiers` scoped to the `gödel_number`/`factor`/`decode` methods — the umlaut is intentional per the card's own method name — and refactored `topological_order` into smaller methods to clear Metrics/AbcSize and MethodLength rather than disabling those, since this is new code with no pre-existing-debt excuse).