---
id: "card-bridge-build-types-reasoningtrace-compute-deriva-1hgfn2r"
boardId: "default"
title: "Bridge: build Types::ReasoningTrace + compute derivation_hash locally"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-source-reasoning-layer-structured-reasoningtrace-0fzkzub"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:46:35.497Z"
updatedAt: "2026-06-25T02:33:10.893Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
New private method in `PassTwoEngine` (`lib/sfl/compiler/pass_two/pass_two_engine.rb`), alongside `interpersonal_from`/`textual_from` (lines 258-303) — same bridge role: DSPy result hash → Dry::Struct.

```ruby
private def reasoning_trace_from(result, conclusion)
  premises = (result[:premises] || []).map do |p|
    Types::Premise.new(type: p.type, source: p.source, value: p.value, weight: p.weight)
  end
  inference_rule = result[:inference_rule] || "unknown"
  generated_at = ::Time.now

  Types::ReasoningTrace.new(
    premises:,
    inference_rule:,
    conclusion:,
    confidence: clamp01(result[:confidence] || 0.5),
    derivation_hash: compute_derivation_hash(premises, inference_rule, conclusion),
    generated_at:
  )
end

private def compute_derivation_hash(premises, inference_rule, conclusion)
  canonical = JSON.generate(
    premises: premises.map(&:to_h).sort_by { |p| [p[:type], p[:source]] },
    inference_rule:,
    conclusion: conclusion.sort.to_h
  )
  Digest::SHA256.hexdigest(canonical)
end
```

**Critical, non-negotiable per this track's brief: `derivation_hash` is computed here, from the actual returned premises/inference/conclusion — never read from an LLM output field.** If a future implementer adds a `derivation_hash` field to `SFLSignature`'s output and trusts it, that's a regression — the hash verifies nothing if the model can just emit whatever string it wants.

Wire into `interpersonal_from` (or call alongside it in `annotate_chunk`/`annotate_interpersonal`) so every `Types::AnnotatedClause` gets a `reasoning_trace` — add the attribute to `Types::InterpersonalPayload` (or `AnnotatedClause`, decide which at implementation time based on whether reasoning is interpersonal-specific or clause-wide) as `Types::ReasoningTrace.optional`, defaulting to nil for non-LLM (`fallback`/`stub`) annotations.

RSpec: same premises+inference_rule+conclusion always produces the same `derivation_hash` (determinism — sort premises before hashing so input-array order doesn't change the hash); different conclusion with same premises produces a different hash; a fallback-sourced clause has `reasoning_trace: nil`.

Acceptance: two `annotate` calls with identical DSPy stub responses produce byte-identical `derivation_hash` values.