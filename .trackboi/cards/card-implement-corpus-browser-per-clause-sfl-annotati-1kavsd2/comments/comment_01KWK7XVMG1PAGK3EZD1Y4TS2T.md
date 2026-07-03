---
id: "comment_01KWK7XVMG1PAGK3EZD1Y4TS2T"
cardId: "card-implement-corpus-browser-per-clause-sfl-annotati-1kavsd2"
createdAt: "2026-07-03T05:41:20.656Z"
updatedAt: "2026-07-03T05:41:20.656Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Closed — superseded, not completed.** ConvoWorkbench already has `GraphExplorer`/`Graph3D`/`GraphInsights` (react-force-graph-3d) and a `ReviewView`+`ConversationList`+`ConversationViewer`+`RatingPanel` list/detail/decision pattern — structurally exactly a corpus browser + annotation review queue, wired to the wrong data model. See new cards "Adapt GraphExplorer/Graph3D into a clause/topic/document Corpus Browser over /retrieve" and "Adapt ReviewView/RatingPanel into the SFL annotation review queue (cross-ref: HITL track)" for the replacement plan.

Note: this card's "annotation_source provenance" requirement is also the exact seed the HITL Annotation Review track's `TUI::EvidencePane` already renders in the terminal — the browser adaptation should reuse the same underlying data (annotation_source, reasoning_trace, fuzzy status), not invent a second provenance model.