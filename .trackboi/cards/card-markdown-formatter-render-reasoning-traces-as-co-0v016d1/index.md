---
id: "card-markdown-formatter-render-reasoning-traces-as-co-0v016d1"
boardId: "default"
title: "Markdown formatter: render reasoning traces as collapsible proof chains"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-source-reasoning-layer-structured-reasoningtrace-0fzkzub"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:46:49.606Z"
updatedAt: "2026-06-25T02:51:41.918Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
`lib/sfl/compiler/formatters/markdown_formatter.rb` (or wherever per-clause detail rendering lives — check against the existing Data Quality section pattern for fallback/stub sourcing) gains a collapsible `<details>` block per clause with a non-nil `reasoning_trace`:

```markdown
<details>
<summary>Reasoning: tenor_high_formal_register (confidence 0.92)</summary>

| Premise | Type | Value | Weight |
|---|---|---|---|
| unanimously | token | ADV | 0.7 |
| approved | token | VERB | 0.5 |
...

Derivation: `a3f2b7c...`
</details>
```

Clauses with `reasoning_trace: nil` (fallback/stub annotation_source) render nothing extra — consistent with this codebase's existing "fallback values aren't presented as findings" principle from the Data Quality section.

RSpec: a clause with a populated trace renders the `<details>` block with all premises listed; a fallback clause's section has no proof-chain block.

Acceptance: running `sfl-analyze conversation` on a fixture with at least one LLM-sourced clause produces a markdown report with a visible collapsible reasoning section for that clause only.