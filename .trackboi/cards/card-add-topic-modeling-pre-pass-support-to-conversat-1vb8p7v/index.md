---
id: "card-add-topic-modeling-pre-pass-support-to-conversat-1vb8p7v"
boardId: "default"
title: "Add topic-modeling pre-pass support to ConversationAnalysisWorkflow"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-gush-conversation-workflow-feature-completeness--087qyay"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T00:57:51.950Z"
updatedAt: "2026-06-25T06:03:53.784Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
`ConversationAnalyzer#analyze`'s `topics:` parameter runs a `TopicModeler.fit` pre-pass over all raw turns before any per-turn compile, attaching `pre_turn.dominant_topic`/`topic_distribution`/`semantic_coherence_score` to each turn and computing `topic_shifts`/`topic_labels` for the final report. `ConversationAnalysisWorkflow#configure` has no equivalent — it only supports `topics: nil`.

Shape (per the original plan's "explicitly out of scope" note, `docs/superpowers/plans/2026-06-24-gush-conversation-workflow.md`): a `TopicModelJob` that runs before the `CompileTurnJob` fan-out (no dependency on it — only needs raw turn text), outputting `pre_turns`/`topic_labels`/`topic_shifts`. Each `CompileTurnJob` would then depend on `TopicModelJob` (`after: [topic_job]`) and read its own turn's `pre_turn` data from `payloads` to attach topic info, mirroring `compile_turn`'s `pre_turn:` parameter today. `ReduceTurnsJob` needs `topic_labels`/`topic_shifts` forwarded into `build_result` too.