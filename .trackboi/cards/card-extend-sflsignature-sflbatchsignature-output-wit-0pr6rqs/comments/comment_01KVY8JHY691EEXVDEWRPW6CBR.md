---
id: "comment_01KVY8JHY691EEXVDEWRPW6CBR"
cardId: "card-extend-sflsignature-sflbatchsignature-output-wit-0pr6rqs"
createdAt: "2026-06-25T02:08:35.782Z"
updatedAt: "2026-06-25T02:08:35.782Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in `lib/sfl/compiler/pass_two/pass_two_engine.rb` (commit eedc3f0): `PremiseOutput < T::Struct`, `premises`/`inference_rule` added to `SFLSignature`'s output, `ClauseAnnotation`, and forwarded by both `SFLAnnotator#call` and `SFLBatchAnnotator#call`. Added a stubbed-DSPy spec proving the fields pass through as real `PremiseOutput` instances, not hashes. Full suite: 327 examples, 0 failures. Pre-existing rubocop Metrics offenses in this file confirmed via `git stash` diff — not introduced by this change, left alone (out of scope). Next: the bridge card (`Types::ReasoningTrace` construction + local `derivation_hash`) is unblocked.