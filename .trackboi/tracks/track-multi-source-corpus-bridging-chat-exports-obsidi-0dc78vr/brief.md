# Multi-Source Corpus Bridging

## Why this track exists

Two ingest domains evolved independently:
- **Chat exports** (Claude.ai, ChatGPT, Mistral LeChat) — ConvoWorkbench's original design target, parsed entirely client-side by the now-deleted `builder.ts`.
- **Obsidian vault** (documents, PDFs, images, canvases) — sfl-compiler's `KnowledgeBaseAnalyzer` design target.

The Corpus Browser card (React Frontend track) assumed a single unified corpus to browse. It isn't one yet — chat exports have no Ruby-side ingest path at all, and the vault path is missing Canvas support and most of kreuzberg's format coverage.

## Sequenced work

1. **`source_type` provenance column** (foundational — everything below depends on it): migration on `clauses` (or wherever it best fits — decide table placement during implementation), threaded through `Types::AnnotatedClause`, `Pipeline#compile`, `ClauseRepository#store`, `HybridRetriever` (new filter), and the Falcon `/retrieve` endpoint's filter whitelist. Values something like: `chat_claude`, `chat_chatgpt`, `chat_mistral`, `chat_native` (existing SillyTavern-format default), `vault_markdown`, `vault_pdf`, `vault_image`, `vault_canvas`, `api` (existing `/pipeline/compile` default) — exact enum finalized during implementation.
2. **Chat export loaders**: `ClaudeExportLoader`, `ChatGPTExportLoader`, `MistralExportLoader`. Normalize each format's actual JSON shape into sfl-compiler's existing turn schema (`name`/`is_user`/`send_date`/`mes`) rather than inventing a parallel ingestion path — reuses `ConversationAnalyzer`/`ConversationAnalysisWorkflow` unchanged, tags `source_type` at compile time. Claude.ai export shape (conversations.json/projects.json/memories.json) and ChatGPT's tree-structured mapping are both known from ConvoWorkbench's deleted `builder.ts` — same parsing logic, reimplemented server-side with test coverage. Mistral LeChat's export shape needs its own research (not previously handled anywhere in this codebase).
3. **Vault format widening**: `CanvasLoader` for Obsidian `.canvas` (JSON node-graph — extract text-bearing nodes as sections, note file-node references). Widen `KnowledgeBaseAnalyzer::TEXT_EXTENSIONS` to kreuzberg's already-wired formats (`.docx`, `.xlsx`, `.pptx`, `.html` at minimum — kreuzberg claims 75+, confirm which ones make sense for a personal vault).
4. **Corpus Browser card update**: once `source_type` exists and both ingest paths populate it, the existing "Adapt GraphExplorer/Graph3D" card's `/retrieve` filter needs a `source_type` facet, and the browser UI needs a source-domain filter chip (chat vs. vault, and per-provider within chat). This card already exists in the React Frontend track — update its description rather than duplicating, once this track's foundational pieces land.

## Explicitly out of scope

- **Audio transcription** — no STT tool in the stack (kreuzberg doesn't do it). Revisit as its own track once a transcription approach is chosen; don't let it block Canvas/chat-export work.
