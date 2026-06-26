---
id: "comment_01KW0K5YAV93C58ZAMWSGRJK2K"
cardId: "card-extend-reduceturnsjob-output-to-forward-full-ana-1ncgrp0"
createdAt: "2026-06-25T23:52:25.691Z"
updatedAt: "2026-06-25T23:52:25.691Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Done — commit 2a74d63.

**What changed:**

`Types` module gains four new loaders:
- `load_speaker_profile(hash)` — `SpeakerProfile.new(hash)` (no Time/nested structs, Dry coerces directly)
- `load_key_moment(hash)` — `KeyMoment.new(hash)`
- `load_example_passage(hash)` — `ExamplePassage.new(hash)`
- `load_analysis_result(hash)` — reconstructs `turns` (via `load_conversation_turn`), `speaker_profiles` (via `to_h { |k, p| [k.to_s, load_speaker_profile(p)] }` — note the key stringification; JSON `symbolize_names: true` makes them symbols after a Gush round-trip, but the rest of the codebase (formatters, profiler) expects string keys), `key_moments`, `example_passages`.

`ReduceTurnsJob#perform` now calls `output(full_output(result, jsonl_path))` instead of a 4-key inline hash. The `full_output` helper forwards all 12 `AnalysisResult` fields; `Types.dump(p)` handles each `SpeakerProfile`/`KeyMoment`/`ExamplePassage` (all Dry::Structs, so `.to_h` + `deep_stringify_time` covers them without extra loaders on the write path).

**Non-obvious design decision:** `speaker_profiles` keys must be stringified on load. `SpeakerProfiler.build_profiles` builds `{ "Alice" => SpeakerProfile }` (string keys). JSON round-trip through Gush with `symbolize_names: true` turns those into `{ Alice: profile_hash }`. Without the `k.to_s` in `load_analysis_result`, `result.speaker_profiles["Alice"]` returns nil for any downstream code that does a string-key lookup.

**Rubocop:** `full_output` needs `rubocop:disable Metrics/AbcSize, Metrics/MethodLength` — 12-key hash literal, structurally impossible to reduce without premature abstraction. No new debt introduced in any other method.

**Verified:** 433 examples, 0 failures. New specs: `load_analysis_result` JSON round-trip in `types_spec.rb`, and a `forwards full AnalysisResult fields` example in `reduce_turns_job_spec.rb`.