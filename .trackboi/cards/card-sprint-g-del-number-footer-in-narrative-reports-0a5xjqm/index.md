---
id: "card-sprint-g-del-number-footer-in-narrative-reports-0a5xjqm"
boardId: "default"
title: "Sprint Gödel-number footer in narrative reports"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-narrative-generation-as-strange-loop-closure-0r3gaye"
column: "backlog"
rank: "jU"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:23:11.273Z"
updatedAt: "2026-06-25T01:51:16.511Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Sprint Gödel-number footer in narrative reports (cross-track dependency).

Once the QuestionGraph class exists (Cross-Document track) AND multi-model narrative generation exists (this track), the narrative report should encode its question graph in the footer so the strange loop can be tracked across runs.

Requirements:
1. When generating a narrative, construct a QuestionGraph from the analysis questions (e.g., "What is the tenor trajectory?", "Are there mood shifts between speakers?").
2. Encode as Gödel number in the narrative footer: `Sprint G_N = <number>`.
3. The footer also includes the generation model and verification model identities for auditability.
4. RSpec: narrative with known question set produces correct Gödel number; factorization recovers the question set.

Acceptance: `sfl-analyze narrate report.json --generation-model haiku --verification-model sonnet` produces a narrative_report.md with footer containing `G_N`, model identities, and question list.