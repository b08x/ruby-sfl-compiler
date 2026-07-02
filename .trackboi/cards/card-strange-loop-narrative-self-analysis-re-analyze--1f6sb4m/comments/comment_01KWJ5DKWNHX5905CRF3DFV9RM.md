---
id: "comment_01KWJ5DKWNHX5905CRF3DFV9RM"
cardId: "card-strange-loop-narrative-self-analysis-re-analyze--1f6sb4m"
createdAt: "2026-07-02T19:38:16.853Z"
updatedAt: "2026-07-02T19:38:16.853Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in commit b37e764.

`Analysis::NarrativeSelfAnalyzer` (`lib/sfl/compiler/analysis/narrative_self_analyzer.rb`):
- `analyze(narrative_text, source_result:)` compiles narrative through the pipeline (`store: false, embed: false`) and compares interpersonal profile against source turns
- Metrics: `tenor_delta`, `modality_delta`, `mood_delta` (L1/2 distance between mood distributions); `strange_loop_divergence` = mean of three, clamped 0–1
- Flags divergence > 0.3; early-returns divergence=1.0 for empty text or empty pipeline output
- Class method `.analyze(narrative_path, pipeline:, source_result:)` for file-based invocation
- 6 specs (all passing): grounded → < 0.1, invented tension → > 0.3, empty → 1.0 + error, plus empty turns, empty pipeline, profile exposure