---
id: "card-strange-loop-narrative-self-analysis-re-analyze--1f6sb4m"
boardId: "default"
title: "Strange-loop narrative self-analysis (re-analyze the narrative)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-narrative-generation-as-strange-loop-closure-0r3gaye"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:23:09.150Z"
updatedAt: "2026-07-02T19:38:16.853Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Strange-loop self-analysis: re-analyze the narrative's own annotations.

The narrative_report.md is itself a document that can be fed back through `sfl-analyze conversation` (or a new lightweight path). This creates the literal strange loop: the compiler analyzes text about the compiler's own categories.

Requirements:
1. New CLI path or method: `NarrativeSelfAnalyzer.analyze(narrative_path)` runs the narrative through Pass 1 + Pass 2 and compares the result against the source document's interpersonal profile.
2. Comparison metrics: tenor_distribution delta, mood_distribution delta, modality_mean delta. A "strange_loop_divergence" score (0-1) measures how much the narrative's interpersonal profile diverges from the source.
3. If divergence > 0.3, the narrative is flagged as potentially hallucinated (the generator invented structure not present in the source).
4. RSpec: (a) a perfectly grounded narrative scores < 0.1 divergence, (b) a narrative with invented "escalating tension" in a flat conversation scores > 0.3, (c) edge case: empty narrative returns divergence=1.0 with error flag.

Acceptance: after generating a narrative, running the self-analyzer produces a divergence report. A narrative that claims "escalating tension" about a conversation with flat tenor scores high divergence and gets flagged.