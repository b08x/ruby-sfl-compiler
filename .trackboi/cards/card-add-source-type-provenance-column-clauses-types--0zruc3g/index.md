---
id: "card-add-source-type-provenance-column-clauses-types--0zruc3g"
boardId: "default"
title: "Add source_type provenance column: clauses → Types → Pipeline → ClauseRepository → HybridRetriever → /retrieve"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-multi-source-corpus-bridging-chat-exports-obsidi-0dc78vr"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T06:31:13.952Z"
updatedAt: "2026-07-03T06:54:58.945Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Foundational — every other card in this track depends on it. `clauses` has no provenance column today (verified 2026-07-03); nothing distinguishes a chat-export clause from a vault-document clause.

1. Migration: add `source_type` (String, not null, default matching current implicit behavior) via the existing `Migrator`/`backfill_columns` pattern (`lib/sfl/compiler/storage/database.rb`).
2. `Types::AnnotatedClause` (and `SyntacticClause`? decide during implementation whether it belongs at the syntactic or top-level clause struct) gains `source_type`.
3. `Pipeline#compile` accepts a `source_type:` param, threads it to storage.
4. `ClauseRepository#store` persists it.
5. `HybridRetriever` gains a `source_type` scalar filter (same pattern as `mood`/`process_type` in `apply_filters`).
6. Falcon `/retrieve` (`validate_filters`) whitelists `source_type`.
7. Existing call sites (CompileTurnJob, CompileSectionJob, KnowledgeBaseAnalyzer, CLI `sfl-analyze knowledge-base`) get sensible defaults so nothing breaks: `chat_native` for the SillyTavern conversation format, `vault_markdown`/`vault_pdf`/`vault_image` for KB loaders, `api` for direct `/pipeline/compile` calls (matches existing `document_id` default pattern).

Acceptance: existing full suite still green with the new column backfilled; a new spec asserts `/retrieve` can filter by `source_type`.