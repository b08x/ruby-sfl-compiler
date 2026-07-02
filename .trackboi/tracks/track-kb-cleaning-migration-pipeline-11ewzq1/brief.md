# KB Cleaning / Migration Pipeline

## What shipped (commit 7eb4420 + 5205db8)

- `MarkdownLoader::Section` — `frontmatter` field added; YAML block is now parsed (title, tags, last updated) instead of stripped
- `ImageLoader` — vision-LLM → Section; off by default (`analyze_images: false`)
- `Types::KnowledgeArtifact`, `Types::MigrationManifestEntry`, `Types::KnowledgeBaseReport`
- `ContentTypeClassifier` — two-stage: frontmatter tags + text patterns first, SFL interpersonal/ideational signals as fallback
- `QualityScorer` — weighted 0-1 from annotation_source reliability (0.40), avg_modality (0.30), clause count (0.20), freshness vs 18-month cutoff (0.10)
- `MigrationAssessor` — decision matrix → keep/update/archive/review; `:ai_generated` → `:review` (verify against ground truth, reword before migrating)
- `KnowledgeBaseAnalyzer` — orchestrates loaders → SFL pipeline → classify → score → assess; returns `KnowledgeBaseReport`
- Full spec coverage: 514 examples passing

## Outstanding

- CLI entry point (`sfl-analyze knowledge-base <path>`)
- `KBFormatter` — dedicated markdown/JSON/CSV output for `KnowledgeBaseReport`
- `PdfLoader` frontmatter — extract PDF metadata (title, author, creation date) into frontmatter-compatible hash
- DB persistence for `KnowledgeArtifact` records (separate table or reuse `clauses` + new `kb_artifacts` table)
- ImageLoader: vision model selection via `.env` / Bootstrap config

## Key design decisions

- `KnowledgeBaseAnalyzer` is a sibling of `DocumentationAnalyzer`, not a replacement — the conversational analyzer still serves `sfl-analyze documentation`
- `:ai_generated` → `:review` (not `:archive`): AI-generated summaries need human verification against ground truth before migration decision
- Image analysis is `analyze_images: false` by default — vision LLM calls are expensive; opt-in per invocation
- Loader duck type: all loaders return via `loader.call(file)` (lambda), no per-type branching in KnowledgeBaseAnalyzer
