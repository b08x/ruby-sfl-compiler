---
id: "card-cli-add-knowledge-base-subcommand-to-sfl-analyze-1lon3km"
boardId: "default"
title: "CLI: add `knowledge-base` subcommand to sfl-analyze"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-kb-cleaning-migration-pipeline-11ewzq1"
column: "done"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T06:26:41.840Z"
updatedAt: "2026-06-26T13:40:48.268Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Wire `KnowledgeBaseAnalyzer` into `cli.rb` as a new `knowledge-base` subcommand alongside `conversation` and `documentation`.

**Signature:**
```
sfl-analyze knowledge-base <path> [--store] [--images] [--vision-model MODEL] [--output-dir DIR]
```

**Flags:**
- `--store` — persist clauses + embeddings via `ClauseRepository`
- `--images` / `--no-images` — enable `analyze_images: true` (default off)
- `--vision-model MODEL` — override vision LLM model id (falls back to `VISION_MODEL` env var)
- `--output-dir DIR` — write report files here (default `./output`)

**Wiring in `cli.rb`:**
- `Bootstrap.call(require_db: opts[:store], require_llm: true)`
- Construct `KnowledgeBaseAnalyzer.new(pipeline:, clause_repo: opts[:store] ? repo : nil, on_progress: progress_cb)`
- Pass result to `KBFormatter` / `ReportWriter`

**Acceptance:** `bundle exec sfl-analyze knowledge-base ~/Notebook --output-dir ./output/kb` produces report files without error.