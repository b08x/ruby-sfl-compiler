---
id: "card-pdfloader-extract-pdf-metadata-into-frontmatter--08zaqvl"
boardId: "default"
title: "PdfLoader: extract PDF metadata into frontmatter-compatible hash"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-kb-cleaning-migration-pipeline-11ewzq1"
column: "done"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T06:26:53.869Z"
updatedAt: "2026-06-26T13:43:47.146Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Currently `PdfLoader` sets `frontmatter: nil` on every section. PDF files carry XMP/metadata (title, author, creation date, keywords) that should feed `ContentTypeClassifier` tag matching and `QualityScorer` freshness scoring.

**Implementation:**
- Kreuzberg (already a dependency) exposes document-level metadata — check if `Kreuzberg::Document` has a metadata accessor
- If not, use `pdf-reader` gem or `exiftool` subprocess fallback
- Map PDF metadata → frontmatter hash: `{ "title" => doc.title, "tags" => doc.keywords, "last updated" => doc.creation_date }`
- Pass the frontmatter hash to every `Section.new` call in `PdfLoader#each_section`

**Acceptance:** A research PDF with a title and keywords produces `KnowledgeArtifact` with non-nil `tags` and `last_updated`.