---
id: "card-extend-sflsignature-sflbatchsignature-output-wit-0pr6rqs"
boardId: "default"
title: "Extend SFLSignature/SFLBatchSignature output with structured premises (Sorbet)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-source-reasoning-layer-structured-reasoningtrace-0fzkzub"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:46:26.207Z"
updatedAt: "2026-06-25T02:08:35.782Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
In `lib/sfl/compiler/pass_two/pass_two_engine.rb`, replace/extend the `reasoning: String` output field (line 481 on `SFLSignature`, line 554 on `ClauseAnnotation`/used by `SFLBatchSignature`) with structured fields, following the exact pattern `ClauseAnnotation < T::Struct` already establishes for the batch path.

```ruby
class PremiseOutput < T::Struct
  const :type,   String   # "token" | "pos" | "dep" | "process" | "participant" | "context" | "lexico_grammatical"
  const :source, String
  const :value,  String
  const :weight, T.nilable(Float)
end
```

Add to `SFLSignature`'s `output do...end` (and the equivalent `ClauseAnnotation` fields used by `SFLBatchSignature`):
```ruby
const :premises,       T::Array[PremiseOutput], description: "Specific tokens/POS/deps/etc. that support this annotation"
const :inference_rule, String, description: "Named SFL rule mapping premises to the conclusion, e.g. 'tenor_high_formal_register'"
```

Keep `reasoning: String` for now as a human-readable summary (don't break the existing Markdown report's prose rendering) — `premises`/`inference_rule` are additive, not a replacement, until the markdown/JSON formatter cards land.

Verified against Context7 (vicentereig/dspy.rb complex-types docs, 2026-06-25): `T::Array[SomeStruct]` output fields auto-coerce LLM JSON array elements into struct instances — same mechanism `SFLBatchSignature.output.annotations: T::Array[ClauseAnnotation]` already relies on at line 574.

RSpec: stub a DSPy response with 2 premises, assert `result.premises.first` is a `PremiseOutput` instance (not a Hash) and `result.premises.first.type` is the string, not coerced to a Ruby symbol/enum (no `T::Enum` needed here — `type` stays a plain validated String per the Dry::Struct enum on the internal side).

Acceptance: `SFLAnnotator.new(context).call` returns a hash including `premises: [...]` (array of T::Struct, not raw hashes) and `inference_rule: "..."`, alongside the existing fields.