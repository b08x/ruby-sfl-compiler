---
id: "card-add-annotation-source-awareness-to-contextsynthe-11jhe4m"
boardId: "default"
title: "Add annotation_source awareness to ContextSynthesizer"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-documentation-deep-dive-with-constraint-pinning-06mnjm7"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:21:54.239Z"
updatedAt: "2026-06-25T06:43:36.791Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Add annotation_source awareness to ContextSynthesizer.

Currently `lib/sfl/compiler/retrieval/hybrid_retriever.rb` and `lib/sfl/compiler/retrieval/context_synthesizer.rb` have NO awareness of clause-level `annotation_source`. When an annotation failed in Pass 2 (marked `fallback` or `stub`), the retriever treats it identically to `llm`-annotated clauses. This violates the Gödel-incompleteness-as-fail-loud principle.

Requirements:
1. `ContextSynthesizer#synthesize` filters fallback/stub clauses BEFORE passing to LLM unless explicitly opted in (e.g. `include_fallback: true` param).
2. The synthesizer's answer includes a "Data Quality" preamble stating how many retrieved clauses carried fallback/stub values.
3. Citations in the answer ONLY cite llm-annotated clauses (fallback/stub cannot be cited as evidence).
4. Add RSpec tests covering: (a) fallback clauses excluded by default, (b) fallback included with `include_fallback: true`, (c) citation markers only on llm clauses.

Acceptance: `sfl-analyze context "query"` over a corpus with known fallback rate produces answer that explicitly states "N/M clauses excluded due to fallback annotation" and never cites those clauses.