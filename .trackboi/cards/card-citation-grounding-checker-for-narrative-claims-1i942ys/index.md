---
id: "card-citation-grounding-checker-for-narrative-claims-1i942ys"
boardId: "default"
title: "Citation grounding checker for narrative claims"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-narrative-generation-as-strange-loop-closure-0r3gaye"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:23:10.209Z"
updatedAt: "2026-07-02T20:00:46.016Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Citation grounding checker: every narrative claim traces to a clause_id.

The Crab agent's constraint: every claim in the narrative MUST cite a clause_id. Uncitied claims are "non-theorems" — structurally invalid outputs that must be flagged.

Requirements:
1. New module `Analysis::CitationGroundingChecker` with `check(narrative_text, source_clauses)` returning { grounded: [...], ungrounded: [...], coverage: Float }.
2. A claim is "grounded" if it contains a valid citation marker (e.g., `[doc-1:clause-42]`) AND the cited clause text semantically supports the claim (simple heuristic: shared keywords OR LLM-based entailment check).
3. Ungrounded claims are listed in a "Hallucination Report" section appended to the narrative.
4. The markdown formatter adds a footer: `Citation coverage: X/Y claims grounded (Z%)`.
5. RSpec: (a) narrative with 100% citation coverage passes, (b) narrative with invented claims flags them, (c) citation to a non-existent clause_id is detected as ungrounded.

Acceptance: a narrative_report.md with 20 claims, 2 of which are invented (no source support), produces a Hallucination Report listing those 2 with "UNGROUNDED" markers and a citation coverage of 90%.