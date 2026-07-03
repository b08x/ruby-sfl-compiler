---
id: "card-adapt-reviewview-ratingpanel-into-the-sfl-annota-144omt3"
boardId: "default"
title: "Adapt ReviewView/RatingPanel into the SFL annotation review queue"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:41:48.744Z"
updatedAt: "2026-07-03T11:57:48.764Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Depends on the GraphContext/Falcon wiring card AND the HITL track's "Design review data model" card (needs the `annotation_source: "human"` value + review-state schema to exist server-side first). `ReviewView.tsx`'s list/detail/decision-panel layout (`ConversationList` + `ConversationViewer` + `RatingPanel`) is structurally the right shape for a review queue — but its rating rubric (correctness/tone/format/style_tags) rates whole conversations on dimensions SFL doesn't use. Replace with: a queue of flagged *clauses* (fallback/stub/fuzzy annotation_source, sourced from the same "needs attention" predicate `TUI::EvidencePane` already implements), evidence display (reasoning trace premises, inference rule, DSPy reasoning text) in place of the message viewer, and accept/re-annotate/reject buttons in place of the rating buttons.

Cross-referenced from the HITL Annotation Review track — this card is the resolution of that track's "surface ownership undecided" question: this browser view and the TUI `EvidencePane` both consume the same review data model and Falcon endpoints, no duplicated logic.