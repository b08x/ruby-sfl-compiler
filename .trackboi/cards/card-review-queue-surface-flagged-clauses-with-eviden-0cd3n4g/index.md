---
id: "card-review-queue-surface-flagged-clauses-with-eviden-0cd3n4g"
boardId: "default"
title: "Review queue surface: flagged clauses with evidence, accept / re-annotate / reject"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-human-in-the-loop-annotation-review-0fn8s9p"
column: "backlog"
rank: "yv"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:29:33.969Z"
updatedAt: "2026-07-03T05:29:33.969Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Interactive queue over the review data model: list clauses flagged fallback/stub/fuzzy, show the evidence for each (reasoning trace premises, inference rule, fuzzy-match provenance, DSPy reasoning text), take a decision. Depends on the data-model card. Surface decision required first (see track brief): TUI pane evolved from EvidencePane vs. Falcon API endpoints consumed by both TUI and the React track's Corpus Browser. If TUI: bubbles list/paginator for the queue, bubblezone if the vision doc's clickable [Accept] [Edit] [Reject] buttons are wanted, keybindings either way.