---
id: "card-kb-annotated-document-output-annotated-flag-1qrsk5j"
boardId: "default"
title: "KB annotated document output (--annotated flag)"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-kb-cleaning-migration-pipeline-11ewzq1"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T04:45:26.761Z"
updatedAt: "2026-07-03T04:45:26.761Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Retroactive card — shipped in d2077c9.

`sfl-analyze knowledge-base --annotated` writes one annotated markdown file per *source document* to `annotated/` under `--output-dir`. `KBAnnotatedDocFormatter` renders one artifact's clauses as a `##` section with inline `[process_type · mood · tenor=N · modality=N]` tags (clause order preserved); `KBAnnotatedDocWriter` groups artifacts sharing a `source_file` into one document and disambiguates same-basename files from different directories. Opt-in, per-artifact (not per-report) — the exception to the report-trio formatter pattern.

Verified end-to-end against output/kb_test03 run.