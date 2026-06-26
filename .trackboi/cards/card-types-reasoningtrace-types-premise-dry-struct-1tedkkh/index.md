---
id: "card-types-reasoningtrace-types-premise-dry-struct-1tedkkh"
boardId: "default"
title: "Types::ReasoningTrace + Types::Premise (Dry::Struct)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-source-reasoning-layer-structured-reasoningtrace-0fzkzub"
column: "done"
rank: "U"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:46:17.803Z"
updatedAt: "2026-06-25T02:04:50.734Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Add to `lib/sfl/compiler/types.rb`:

```ruby
class Premise < Dry::Struct
  attribute :type,   Types::String.enum("token", "pos", "dep", "process", "participant", "context", "lexico_grammatical")
  attribute :source, Types::String
  attribute :value,  Types::String
  attribute :weight, Types::Float.optional
end

class ReasoningTrace < Dry::Struct
  attribute :premises,        Types::Array.of(Premise)
  attribute :inference_rule,  Types::String
  attribute :conclusion,      Types::Hash
  attribute :confidence,      Types::Float.constrained(gteq: 0.0, lteq: 1.0)
  attribute :derivation_hash, Types::String
  attribute :generated_at,    Types::Time
end
```

These are internal representations only — DSPy never produces them directly (see the sibling card for the Sorbet-side `PremiseOutput < T::Struct`). Use the existing `::Time` gotcha from `bootstrap.rb`'s comment history: inside `module Types; include Dry.Types(); ...`, a bare `Time` resolves to `Types::Time`, not Ruby's `Time` — `generated_at` needs `attribute :generated_at, Types::Time` which is correct (it's the Dry type), but any constructor code building one of these must pass `::Time.now`, not assume `Time.now` resolves correctly inside `Types`' own methods.

Add `Types.dump`/load-side handling consistent with the existing `deep_stringify_time` pattern (used for Gush JSON round-tripping) if `ReasoningTrace` ever crosses a JSON boundary (it does — see the JSON formatter card).

RSpec: construct a `ReasoningTrace` with 2 premises, assert `confidence` rejects values outside 0.0-1.0 (Dry::Struct::Error), assert `Premise#type` rejects an unlisted enum value.

Acceptance: `Types::ReasoningTrace.new(premises: [...], inference_rule: "tenor_high_formal_register", conclusion: {tenor: 0.8}, confidence: 0.92, derivation_hash: "abc...", generated_at: ::Time.now)` constructs without error.