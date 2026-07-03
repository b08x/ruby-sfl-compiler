---
id: "card-canvasloader-widen-knowledgebaseanalyzer-to-kreu-1gbchup"
boardId: "default"
title: "CanvasLoader + widen KnowledgeBaseAnalyzer to kreuzberg's DOCX/XLSX/PPTX/HTML"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-multi-source-corpus-bridging-chat-exports-obsidi-0dc78vr"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T06:31:24.593Z"
updatedAt: "2026-07-03T07:35:28.663Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Depends on the source_type card. Two independent pieces, same card since both touch `KnowledgeBaseAnalyzer`'s loader dispatch:

1. **CanvasLoader** for Obsidian `.canvas` files (JSON node-graph: nodes have type text/file/link/group with x/y/width/height). Extract text-bearing nodes as sections; note file-node references (don't attempt to resolve/inline the linked file's content — that's a separate vault file the analyzer will hit on its own pass). `source_type: vault_canvas`.
2. **Widen `TEXT_EXTENSIONS`**: kreuzberg (already wired into `PdfLoader`, currently the only format using it) claims 75+ formats — extend `KnowledgeBaseAnalyzer` to route `.docx`/`.xlsx`/`.pptx`/`.html` (and any others that make sense for a personal vault, confirm during implementation) through kreuzberg extraction the same way `PdfLoader` does. `source_type: vault_docx`/`vault_xlsx`/etc., or a single `vault_document` — decide granularity during implementation.

Explicitly NOT in scope: audio transcription (see track's out-of-scope note).

Acceptance: a `.canvas` file and at least one widened format (e.g. `.docx`) produce artifacts through the existing `knowledge-base` CLI subcommand with correct `source_type`.