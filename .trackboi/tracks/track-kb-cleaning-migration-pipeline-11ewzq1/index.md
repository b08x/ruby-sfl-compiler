---
id: "track-kb-cleaning-migration-pipeline-11ewzq1"
title: "KB Cleaning / Migration Pipeline"
slug: "kb-cleaning-migration-pipeline"
createdAt: "2026-06-26T06:26:30.876Z"
updatedAt: "2026-07-03T04:45:13.490Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Analysis pipeline treating a file corpus as a knowledge base to clean and migrate rather than a conversation to analyse. Each document section becomes a `KnowledgeArtifact` (content-type classification, quality score, migration-action recommendation), replacing the conversational metaphor for document-corpus use cases.

**Core pipeline shipped** (CLI `knowledge-base` subcommand, KB formatters trio, PdfLoader metadata, ImageLoader vision wiring). **Late-June/July hardening also shipped** (commits d2077c9, c7ab6b3, 9f32144):
- `--annotated` flag: per-source-document annotated markdown output with inline `[process_type · mood · tenor · modality]` clause tags (`kb_annotated_doc_formatter/writer`)
- Batch resilience: per-artifact rescue (skip + `[WARN]` + `skipped`/`skipped_count` metadata) so one malformed vault file can't abort a 1295-artifact run; frontmatter `title:` Date→String coercion (unquoted `title: 2026-06-08` in Daily notes crashed Dry::Struct)
- Classification robustness feeding KB runs: Jaro-Winkler fuzzy fallback in `ClassificationRegistry` (threshold 0.92) + observed-alias expansion (`neutral`→declarative etc.)

Open direction (no cards yet): validate on a full `~/Notebook` corpus run; possible TopicModeler integration for content-type signals.