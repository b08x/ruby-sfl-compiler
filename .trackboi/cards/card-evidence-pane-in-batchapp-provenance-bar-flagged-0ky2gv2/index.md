---
id: "card-evidence-pane-in-batchapp-provenance-bar-flagged-0ky2gv2"
boardId: "default"
title: "Evidence pane in BatchApp: provenance bar + flagged clauses + trace summary"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-human-in-the-loop-annotation-review-0fn8s9p"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:29:25.866Z"
updatedAt: "2026-07-03T05:29:25.866Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Shipped 2026-07-03. `TUI::EvidencePane` (pure renderer, no Bubbletea/Redis state) toggled with `e` in `BatchApp` once a `--live` run finishes. Renders from the reduce job's output payload (`result[:turns][*][:clauses]`):

- **Provenance bar**: segmented llm/fallback/stub coverage (green/yellow/dim) with counts — the honest analogue of the vision doc's "confidence heatmap" (categorical provenance, not a fake scalar)
- **Needs attention**: up to 6 non-llm clauses with source tags + overflow count — the seed of the future review queue
- **Reasoning traces**: traced/total coverage, avg verified confidence, top inference rules

Degrades explicitly on older payloads without `turns` data. 8 specs (`spec/sfl/compiler/tui/evidence_pane_spec.rb`), suite 696/0. Registered in the `tui.rb` manifest (gotcha #9 pattern).