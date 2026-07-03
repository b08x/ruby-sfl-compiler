---
id: "comment_01KWKSTWF8C9D7AD40GNW0X6ZR"
cardId: "card-design-review-data-model-review-state-human-anno-0y4x7z2"
createdAt: "2026-07-03T10:54:17.576Z"
updatedAt: "2026-07-03T10:54:17.576Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done.** Chose the separate-table option (`annotation_reviews`) per the track brief's recommendation — the original machine annotation is never overwritten, only audited alongside a human decision.

- Schema: `annotation_reviews` table (`Migrator#create_annotation_reviews_table`), keyed on `clause_id` like the other payload tables (no real FK).
- `Types::AnnotationSource` gains `"human"`. Added `Types::TRUSTED_ANNOTATION_SOURCES = %w[llm human]` as the single source of truth for "reviewed/reliable" — replaces 7 independent `!= "llm"` checks that predated this value.
- `ClauseRepository#record_review` / `#reviews_for` for persistence (audit-trail only — doesn't flip `annotation_source`; that's the re-annotation card's job).
- Every consumer audited per the acceptance criteria: `QualityScorer::SOURCE_WEIGHTS`, `KnowledgeBaseAnalyzer`/`JSONFormatter`/`NarrativeGenerator`'s `annotation_coverage` (new `human:` bucket, shared equivalence-contract formula kept in sync), `ConversationAnalyzer`/`DocumentationAnalyzer`/`CLI`'s defaulted-count predicates, `KBAnnotatedDocFormatter`/`KBMarkdownFormatter`'s warning tags, `EvidencePane#flagged_section` (human-reviewed clauses no longer show under "Needs attention" — the explicit acceptance bar), `ContextSynthesizer#llm_sourced?` (human-sourced clauses are citable).

Verified: 750 examples / 0 failures across seeds 1, 2, 7633. Rubocop: only cosmetic offenses matching pre-existing per-file conventions, no new offense classes. Committed as `e2f8282`.

Unblocks: "Review queue surface" and "Single-clause re-annotation path" (this track) and "Adapt ReviewView/RatingPanel" (React track).