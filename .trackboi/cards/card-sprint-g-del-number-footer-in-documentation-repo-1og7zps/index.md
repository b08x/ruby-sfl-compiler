---
id: "card-sprint-g-del-number-footer-in-documentation-repo-1og7zps"
boardId: "default"
title: "Sprint Gödel-number footer in documentation reports"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-documentation-deep-dive-with-constraint-pinning-06mnjm7"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T01:21:57.411Z"
updatedAt: "2026-06-25T05:39:45.859Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Sprint report footer encoding Gödel number for cross-run question tracking.

Once the QuestionGraph class exists (from the Cross-Document track), the documentation sprint should write its Gödel-encoded question graph into the narrative report footer so future sprints can recover the full question set.

Requirements:
1. When `--sprint-id` is provided OR when `store: true` is used with documentation analysis, compute the sprint's question graph (which questions were asked, which were deferred) as a Gödel number written into the report: `Sprint G_N = <number>`.
2. The markdown report footer includes a compact section: `Sprint ID / G_N / Questions: <list of question IDs>`.  
3. If no QuestionGraph is constructed (default), omit the footer section — backward compatible with current behavior.
4. RSpec: a documentation run with `--sprint-id sprint-001` produces the footer; without the flag, no footer.

Acceptance: running `sfl-analyze documentation doc.md --store --sprint-id sprint-001` generates a report with `Sprint G_N = <number>` in the footer. Running without `--sprint-id` produces no footer (unchanged behavior).