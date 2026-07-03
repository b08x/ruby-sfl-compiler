---
id: "card-kb-batch-resilience-per-artifact-skip-frontmatte-106wy73"
boardId: "default"
title: "KB batch resilience: per-artifact skip + frontmatter Date-title coercion"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-kb-cleaning-migration-pipeline-11ewzq1"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T04:45:32.398Z"
updatedAt: "2026-07-03T04:45:32.398Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Retroactive card — shipped in c7ab6b3. Root-caused from a live crash: `exe/sfl-analyze knowledge-base ~/Notebook/Daily/` died at artifact 10/1295 with `Dry::Struct::Error: Date has invalid type for :title`.

Root cause: unquoted `title: 2026-06-08` in Daily-note frontmatter parses as a YAML Date (safe_load permits Date for `last updated:`); `section_title` passed it raw into String-typed `KnowledgeArtifact#title`. 6 trigger files confirmed in ~/Notebook/Daily/.

Fixes (defense-in-depth):
1. `section_title` coerces via `.to_s`, blank falls through to heading/file_id
2. Per-artifact `rescue => e` in `KnowledgeBaseAnalyzer#analyze`: skip + `[WARN]` + `metadata[:skipped]`/`[:skipped_count]` — one bad file can no longer abort a whole-corpus run (Interrupt still aborts)
3. Regression specs for Date-title, blank-title fallback, per-artifact failure

688 examples, 0 failures at merge.