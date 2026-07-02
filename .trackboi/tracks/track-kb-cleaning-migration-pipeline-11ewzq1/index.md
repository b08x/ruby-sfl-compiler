---
id: "track-kb-cleaning-migration-pipeline-11ewzq1"
title: "KB Cleaning / Migration Pipeline"
slug: "kb-cleaning-migration-pipeline"
createdAt: "2026-06-26T06:26:30.876Z"
updatedAt: "2026-06-26T06:26:30.876Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
New analysis pipeline for treating a file corpus as a knowledge base to clean and migrate rather than a conversation to analyse. Each document section becomes a `KnowledgeArtifact` with content-type classification, quality score, and migration-action recommendation. Replaces the conversational metaphor (`ConversationTurn`, `SpeakerProfiler`) for document-corpus use cases.