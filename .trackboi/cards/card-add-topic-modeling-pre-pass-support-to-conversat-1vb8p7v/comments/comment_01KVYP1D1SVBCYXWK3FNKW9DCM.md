---
id: "comment_01KVYP1D1SVBCYXWK3FNKW9DCM"
cardId: "card-add-topic-modeling-pre-pass-support-to-conversat-1vb8p7v"
createdAt: "2026-06-25T06:03:53.784Z"
updatedAt: "2026-06-25T06:03:53.784Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Done — commit 90ca9a2.

Implemented exactly per the card's own design: `TopicModelJob` (no dependency on `CompileTurnJob`, reloads `jsonl_path` itself rather than passing raw turns through Redis), each `CompileTurnJob` depends on it (`after: [topic_job]`) and reads its own `pre_turn` by `turn_id`, and `ReduceTurnsJob` forwards `topic_labels`/`topic_shifts` into `build_result`.

**One non-obvious gotcha worth flagging for future jobs reading `topic_labels` from `payloads`**: topic ids round-trip through Gush's JSON-backed payloads as Hash *keys* (`topic_labels: {0 => [...]}`), and JSON always stringifies object keys — unlike Hash *values* (e.g. `dominant_topic` itself), which stay Integers through the round trip. Both `CompileTurnJob` and `ReduceTurnsJob` restore Integer keys via `transform_keys` before indexing `topic_labels[dominant_topic]`; a unit test in `topic_model_job_spec.rb` explicitly asserts the stringified-key behavior so this doesn't silently regress.

Also caught and fixed in `ReduceTurnsJob`: once `TopicModelJob` becomes a *direct* dependency (needed so its payload is reachable at all — Gush only exposes direct-dependency payloads), `payloads` now contains an entry whose shape is completely different from a `ConversationTurn` dump. Added a `p[:class] == CompileTurnJob.to_s` filter before reconstruction — previously every payload was assumed to be a turn.

Verified: new specs for all three jobs/workflow covering both the `topics: nil` (unchanged) and `topics: 2` paths, including a real Redis/Sidekiq-inline end-to-end workflow run (not mocked) confirming `topics_enabled: true` reaches the final reduced result. Full suite 406/0. Rubocop diff confirms zero new debt on already-debt-laden files; the one genuinely new method (`ConversationAnalysisWorkflow#configure`'s `MethodLength` offense) was refactored away rather than left, since new code has no pre-existing-debt excuse.