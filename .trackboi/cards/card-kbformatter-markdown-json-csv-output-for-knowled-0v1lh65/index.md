---
id: "card-kbformatter-markdown-json-csv-output-for-knowled-0v1lh65"
boardId: "default"
title: "KBFormatter — markdown/JSON/CSV output for KnowledgeBaseReport"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-kb-cleaning-migration-pipeline-11ewzq1"
column: "done"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T06:26:48.993Z"
updatedAt: "2026-06-26T13:37:59.371Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
New formatter classes for `Types::KnowledgeBaseReport`, parallel to the existing CSV/JSON/Markdown formatters for `AnalysisResult`.

**Files:**
- `lib/sfl/compiler/formatters/kb_markdown_formatter.rb`
- `lib/sfl/compiler/formatters/kb_json_formatter.rb`
- `lib/sfl/compiler/formatters/kb_csv_formatter.rb`
- Update `lib/sfl/compiler/formatters.rb` manifest

**Markdown output sections:**
1. Executive summary — artifact count, quality distribution table, staleness flag count
2. Migration manifest table — `| # | Title | File | Type | Quality | Action | Reason |`
3. Per-content-type breakdown with artifact lists
4. Staleness flags (artifacts older than 18 months)
5. Data quality preamble if any `fallback`/`stub` annotations present

**JSON output:** Full `KnowledgeBaseReport#to_h` (Types.dump-compatible).

**CSV output:** One row per artifact: `artifact_id, title, source_file, section_path, content_type, quality_score, migration_action, tags, last_updated, llm_clause_count, fallback_clause_count`.

**Note:** Add to `lib/sfl/compiler/formatters.rb` manifest (same pattern as other formatters).