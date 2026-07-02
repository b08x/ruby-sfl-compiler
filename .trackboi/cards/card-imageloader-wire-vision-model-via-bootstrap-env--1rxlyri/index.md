---
id: "card-imageloader-wire-vision-model-via-bootstrap-env--1rxlyri"
boardId: "default"
title: "ImageLoader: wire vision model via Bootstrap / env config"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-kb-cleaning-migration-pipeline-11ewzq1"
column: "done"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T06:26:58.484Z"
updatedAt: "2026-06-26T13:45:14.690Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
`ImageLoader` currently accepts `vision_model:` as a keyword argument, but there is no env-var or Bootstrap config path for it.

**Changes:**
- Add `VISION_MODEL` to `.env.example` with a comment explaining it must be a vision-capable model (e.g. `claude-sonnet-4-6`, `gpt-4o`)
- Read `VISION_MODEL` in `Bootstrap.call` (alongside `EMBEDDING_MODEL`)
- Thread it through `KnowledgeBaseAnalyzer#analyze(vision_model: Bootstrap.config.vision_model)`
- `ImageLoader#describe_image` falls back to `fallback_description` when `VISION_MODEL` is unset (current behaviour — no regression)

**Acceptance:** `VISION_MODEL=claude-sonnet-4-6 bundle exec sfl-analyze knowledge-base ~/Notebook --images` runs without ArgumentError.