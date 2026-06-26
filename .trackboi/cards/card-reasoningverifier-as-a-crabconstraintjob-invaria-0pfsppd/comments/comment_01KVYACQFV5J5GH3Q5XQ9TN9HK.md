---
id: "comment_01KVYACQFV5J5GH3Q5XQ9TN9HK"
cardId: "card-reasoningverifier-as-a-crabconstraintjob-invaria-0pfsppd"
createdAt: "2026-06-25T02:40:22.011Z"
updatedAt: "2026-06-25T02:40:22.011Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in commit 653788c — but with a real fix to the card's own draft design.

The card's example invariant (`check: ->(trace) { compute_derivation_hash(...) == trace.derivation_hash }`) is a Proc, exactly the shape `CrabConstraintJob`'s first card already caught and rejected (Procs can't survive `Gush::Job#to_json`'s Redis serialization). Resolved by adding `"derivation_hash_reproducible"` as a recognized **op value** (data, not code) handled as a special case in `#first_violation` — it operates on the whole claim (recompute from the claim's own premises/inference_rule/conclusion, compare to its own stored hash) rather than the field/op/value DSL the other operators use.

Also extracted `PassTwoEngine`'s hashing algorithm into a shared `SFL::Compiler::DerivationHash` module so both sides (compute-time in `PassTwoEngine`, re-verify-time in `CrabConstraintJob`) use one implementation — two independently maintained copies of "did this get tampered with" would silently drift apart, defeating the check. Hardened it to stringify keys before hashing, since `PassTwoEngine` sees live `Dry::Struct` instances (symbol-keyed `#to_h`) while `CrabConstraintJob` sees plain Hashes that already went through a Redis JSON round trip (string→symbol per `symbolize_names`) — both paths now hash identically regardless of key type.

7 new specs on `CrabConstraintJob` (untouched trace passes, hand-corrupted hash rejected with the values in the reason string, a real 2-trace batch correctly partitioned) plus 4 new specs directly on `DerivationHash` (determinism, premises-order independence, conclusion-sensitivity, symbol/string-key equivalence). Full suite: 351 examples, 0 failures.

This closes out the last open item for the Source Reasoning Layer's "make annotations verifiable" goal short of the formatter cards (markdown/JSON), which are next in the sequence.