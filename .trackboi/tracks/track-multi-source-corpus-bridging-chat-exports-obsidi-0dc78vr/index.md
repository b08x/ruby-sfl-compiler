---
id: "track-multi-source-corpus-bridging-chat-exports-obsidi-0dc78vr"
title: "Multi-Source Corpus Bridging (chat exports + Obsidian vault, unified search)"
slug: "multi-source-corpus-bridging-chat-exports-obsidian-vault-unified-search"
createdAt: "2026-07-03T06:30:58.714Z"
updatedAt: "2026-07-03T06:31:38.389Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
ConvoWorkbench was designed for chat-UI exports (Claude.ai web, ChatGPT, Mistral LeChat). sfl-compiler was designed for genai session logs (its own SillyTavern-style JSONL) and Obsidian vaults (document/PDF/image, via `KnowledgeBaseAnalyzer`). These are two disjoint ingest domains that have never shared a search surface — bridging them is a prerequisite for the Corpus Browser card actually being a *corpus* browser rather than a vault-only one.

Grounded findings (2026-07-03, not assumed): `clauses` table has no source/provenance column today — nothing to facet on. No Ruby-side parser exists for Claude.ai/ChatGPT/Mistral LeChat's actual export JSON shapes (only sfl-compiler's own turn format). `KnowledgeBaseAnalyzer` handles `.md`/`.pdf`/images only — no Canvas, no audio. `kreuzberg` (already a dependency) supports 75+ formats but is only wired into `.pdf` today — widening to DOCX/XLSX/PPTX/HTML is cheap. Kreuzberg does not do speech-to-text; audio transcription needs a tool not yet in the stack.

Three architecture decisions made with the user before any code:
1. Chat-export parsing lives as Ruby-side loader classes (not client-side, not a one-off script) — consistent with the "no client-side duplication of server logic" principle from the Falcon-wiring card.
2. Provenance is an explicit `source_type` column (migration + backfill), not an implicit `document_id` naming convention — queryable/filterable in `/retrieve` and the Corpus Browser.
3. Audio is explicitly deferred — no STT tool in the stack; scope this track to Canvas + widened document formats + the three chat exports.