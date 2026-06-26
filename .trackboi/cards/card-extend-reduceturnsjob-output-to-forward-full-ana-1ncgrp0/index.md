---
id: "card-extend-reduceturnsjob-output-to-forward-full-ana-1ncgrp0"
boardId: "default"
title: "Extend ReduceTurnsJob#output to forward full AnalysisResult"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-tui-overhaul-gush-sidekiq-backed-pycall-safe-0d27wx2"
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T00:40:05.818Z"
updatedAt: "2026-06-25T23:52:25.691Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Prerequisite for the TUI consumer: `lib/sfl/compiler/jobs/reduce_turns_job.rb#perform` currently only forwards `jsonl_path`/`turn_count`/`metadata`/`insights` to `output(...)`, discarding `speaker_profiles`/`tenor_timeline`/`field_evolution`/`correlations`/`key_moments`/`example_passages`/`topic_*` from the `Types::AnalysisResult` it builds. The TUI's live view needs these to show anything beyond a bare progress count. Flagged as a Backlog item in the final SIFT audit of the Gush workflow plan (2026-06-24). Needs `Types.dump` extended to cover `AnalysisResult`'s nested timelines/profiles (not just `ConversationTurn`) since the output must stay JSON-round-trippable through Redis.