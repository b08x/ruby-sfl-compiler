---
id: "card-chat-export-loaders-claudeexportloader-chatgptex-01zg6c0"
boardId: "default"
title: "Chat export loaders: ClaudeExportLoader, ChatGPTExportLoader, MistralExportLoader"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-multi-source-corpus-bridging-chat-exports-obsidi-0dc78vr"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T06:31:19.578Z"
updatedAt: "2026-07-03T07:35:28.069Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Depends on the source_type card. Three Ruby-side loaders normalizing each export's actual JSON shape into sfl-compiler's existing turn schema (`name`/`is_user`/`send_date`/`mes`), tagging `source_type: chat_claude`/`chat_chatgpt`/`chat_mistral` at compile time — reuses `ConversationAnalyzer`/`ConversationAnalysisWorkflow` unchanged rather than inventing a parallel path.

- **ClaudeExportLoader**: `conversations.json` + optional `projects.json`/`memories.json`. Shape known from ConvoWorkbench's deleted `builder.ts` (`ClaudeConversation`/`ClaudeMessage`/`ClaudeProject`/`ClaudeMemory` — sender human/assistant, content blocks including tool_use artifacts).
- **ChatGPTExportLoader**: `conversations.json`, tree-structured `mapping` (parent/children pointers) requiring leaf-to-root traversal + reversal to linearize a thread, filtering system-role nodes. Shape also known from the deleted `builder.ts`.
- **MistralExportLoader**: shape not previously handled anywhere in this codebase — needs its own research (obtain a real LeChat export or find documented format) before implementation.

Acceptance: given a real (or realistic fixture) export file per provider, produces valid turn JSONL that `ConversationAnalyzer` compiles without modification, with clauses carrying the correct `source_type`.