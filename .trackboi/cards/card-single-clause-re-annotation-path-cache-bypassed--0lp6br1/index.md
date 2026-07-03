---
id: "card-single-clause-re-annotation-path-cache-bypassed--0lp6br1"
boardId: "default"
title: "Single-clause re-annotation path: cache-bypassed Pass 2 + targeted repository update"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-human-in-the-loop-annotation-review-0fn8s9p"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:29:39.077Z"
updatedAt: "2026-07-03T11:04:22.876Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
"Re-annotate" decision handler: re-run `PassTwoEngine#annotate` (single-clause path, exists today) for one flagged clause with the resume cache bypassed (otherwise the cache returns the same bad annotation), then persist via a new targeted update in `ClauseRepository` (currently only store/find/delete_by_document). Dispatch as a job + poll rather than in the TUI process (PyCall-free rule; Pass 2 is LLM-only but consistency with the process model is worth more than the shortcut). Re-annotated result re-enters the queue as pending until accepted — a human triggered it, but the annotation is still machine-made, so `annotation_source` stays `llm`.