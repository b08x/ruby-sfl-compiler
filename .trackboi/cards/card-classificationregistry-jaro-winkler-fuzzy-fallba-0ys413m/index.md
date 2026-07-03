---
id: "card-classificationregistry-jaro-winkler-fuzzy-fallba-0ys413m"
boardId: "default"
title: "ClassificationRegistry Jaro-Winkler fuzzy fallback + observed-alias expansion"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-kb-cleaning-migration-pipeline-11ewzq1"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T04:45:38.515Z"
updatedAt: "2026-07-03T04:45:38.515Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Retroactive card — shipped in c7ab6b3/9f32144 (amatch moved to gemspec runtime dep).

`ClassificationRegistry.normalize` gains a last-resort Jaro-Winkler fuzzy match (amatch gem) before defaulting: unknown values ≥4 chars are matched against precomputed frozen candidate pools (canonicals + alias keys), resolving through the alias table. Threshold 0.92 empirically calibrated: true near-misses score ≥0.9378 ("subjective"→"subjunctive" 0.944), worst garbage collision 0.809 ("performative"→"imperative"). New `:fuzzy` status logged as `pass_two_fuzzy_match` WARN.

Alias expansion from live-run WARNs: `neutral`→declarative (6× in one KB run — LLM's "no marked mood" = SFL unmarked declarative), `interjectional`/`interjection`→minor, compound-theme "X and Y"→multiple.

Board-wide benefit but filed here: KB corpus runs over unstructured vault prose are what surfaced the long tail.