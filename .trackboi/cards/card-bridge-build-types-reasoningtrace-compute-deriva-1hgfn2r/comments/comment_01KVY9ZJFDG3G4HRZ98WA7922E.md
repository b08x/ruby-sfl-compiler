---
id: "comment_01KVY9ZJFDG3G4HRZ98WA7922E"
cardId: "card-bridge-build-types-reasoningtrace-compute-deriva-1hgfn2r"
createdAt: "2026-06-25T02:33:10.893Z"
updatedAt: "2026-06-25T02:33:10.893Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in `lib/sfl/compiler/pass_two/pass_two_engine.rb` (commit ad3c78c), following the card's pseudocode closely. `Types::InterpersonalPayload` gained `reasoning_trace: ReasoningTrace.optional.default(nil)` so the fallback path (`default_interpersonal`) needed zero changes — nil falls out of the attribute default automatically.

One behavior worth recording since it wasn't explicit in the card: an `"llm"`-sourced annotation whose DSPy response simply didn't include `premises` still gets a `ReasoningTrace` (with an empty `premises` array and `inference_rule: "unknown"`), not `nil`. Only non-LLM (`fallback`/`stub`) annotations get `reasoning_trace: nil`. This reads as correct: `nil` means "not LLM-annotated at all," not "LLM-annotated without provenance."

5 specs covering exactly the card's RSpec list (attached for llm-sourced, nil for fallback, byte-identical hash across two identical calls, different hash for a different conclusion) plus one not explicitly asked for but worth having: same hash regardless of premises array order (the `sort_by` in `compute_derivation_hash` is what guarantees this — added the test to lock that guarantee in). Full suite: 344 examples, 0 failures.

Next: `ReasoningVerifier as a CrabConstraintJob invariant` is now unblocked (depends on this card + the already-shipped `CrabConstraintJob`).