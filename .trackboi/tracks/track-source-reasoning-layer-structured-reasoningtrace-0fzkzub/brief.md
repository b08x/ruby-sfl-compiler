## Why this exists

`InterpersonalPayload#reasoning` today is free text from `SFLSignature`/`SFLBatchSignature`'s `reasoning: String` output field (`lib/sfl/compiler/pass_two/pass_two_engine.rb:481,554`) — e.g. "uses formal terminology, suggesting formal register." Three problems: unstructured (unqueryable/unscoreable), nothing downstream consumes it, and it captures *what the model said* without *what evidence in the input it actually used*.

## The tripartite model

```
Input Evidence (P1 output)
  → Premise Layer    (which tokens/POS/deps support this annotation?)
  → Inference Layer   (which SFL rule maps premises → annotation?)
  → Conclusion         (mood/tenor/modality/speaker_attitude)
  → derivation_hash   (SHA256 of premises+inference+conclusion — COMPUTED IN RUBY, never an LLM field)
```

## Corrected from the original proposal (verified against real code + Context7, 2026-06-25)

1. **DSPy's structured-output boundary is Sorbet, not Dry::Struct.** `pass_two_engine.rb` already proves this pattern: `ClauseAnnotation < T::Struct` is the batch output type DSPy.rb actually returns (confirmed via Context7 against vicentereig/dspy.rb's complex-types docs — `T::Array[SomeStruct]` output fields auto-coerce). So: a new `PremiseOutput < T::Struct` (Sorbet) goes on `SFLSignature`/`SFLBatchSignature`'s `output do...end` block and on `ClauseAnnotation`. The `Types::ReasoningTrace`/`Types::Premise` (Dry::Struct, in `types.rb`) are the *internal* representation, built by bridge code — same role `interpersonal_from`/`textual_from` already play for `mood`/`tenor`/etc.
2. **`derivation_hash` is not an LLM output field.** If the model computes its own hash, it verifies nothing — it can emit anything. The bridge code (wherever `interpersonal_from` lives today) computes `SHA256(canonical_json(premises + inference + conclusion))` itself, after the LLM call returns the premises/inference/conclusion.

## Concrete touchpoints (one card each)

| Component | Change |
|---|---|
| `Types::ReasoningTrace` + `Types::Premise` | New Dry::Struct types in `types.rb` |
| `SFLSignature`/`SFLBatchSignature`/`ClauseAnnotation` output | Add Sorbet `PremiseOutput < T::Struct`, `premises:`, `inference_rule:` fields (replacing/extending the existing `reasoning: String` field) |
| Bridge in `pass_two_engine.rb` | New method alongside `interpersonal_from`/`textual_from`: builds `Types::ReasoningTrace` from the DSPy result hash, computes `derivation_hash` locally |
| `ReasoningVerifier` | Independently re-derives premises→hash, flags divergence — **this is rule-based, maps onto `CrabConstraintJob`** from `track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi` rather than a bespoke verifier class |
| Markdown formatter | Render reasoning traces as collapsible proof chains |
| JSON formatter | Include `reasoning_trace` in serialized output |

## GEBTrace signal mapping (from the original proposal, unchanged)

| GEBTrace Signal | Source Reasoning Equivalent |
|---|---|
| Confidence Collapse | `confidence` drops across annotations → model uncertain |
| Level Desync | premises from lexical level but inference at discourse level → structural skip |
| RLHF Category Error | `inference_rule` describes social-contract reasoning ("sounds formal to me") vs. a structural rule ("DET+ADV+VERB pattern → formal register") |

## Relationship to other tracks

- `track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi`: `ReasoningVerifier`'s hash-recomputation check is a `CrabConstraintJob` invariant, not new infrastructure.
- `track-documentation-deep-dive-with-constraint-pinning-06mnjm7`: that track's Crab already pins `annotation_source='llm' required` — a structured `derivation_hash` is strictly richer provenance than that flag and could subsume it, but this is a Pass-2-wide change (affects conversation analysis too), not documentation-specific. Informational cross-reference only.
