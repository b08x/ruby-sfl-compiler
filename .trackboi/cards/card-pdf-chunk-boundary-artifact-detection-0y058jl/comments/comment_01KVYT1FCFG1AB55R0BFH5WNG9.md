---
id: "comment_01KVYT1FCFG1AB55R0BFH5WNG9"
cardId: "card-pdf-chunk-boundary-artifact-detection-0y058jl"
createdAt: "2026-06-25T07:13:50.479Z"
updatedAt: "2026-06-25T07:13:50.479Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done. One scope reduction, one significant discovery — both documented below.**

**Scope reduction:** the card mentions an "alternatively" heuristic (spaCy sentence-boundary detection spanning the chunk boundary). Not implemented — it would require re-running sentence segmentation across two chunks the syntactic engine never saw as contiguous text, a materially bigger change than the four literal requirements ask for. Implemented only the primary heuristic (terminal punctuation + continuation-start), documented as a deliberate scope limit in the class comment.

**Discovery: `PdfLoader`'s own comment is wrong (or stale).** It currently reads *"Kreuzberg's own Config::Chunking is real and sentence-boundary-aware (confirmed live: never splits mid-sentence)"*. I generated a real PDF via pandoc (5 paragraphs, ~2.3KB) and ran it through the real `Kreuzberg.extract_file_sync` with the loader's actual `DEFAULT_CHUNKING` config — it produced 3 chunks, and chunk 0→1 **is** a real mid-sentence split: chunk 0 ends `"...credited the improvement to both the"` (no terminal punctuation), chunk 1 opens `"partitioning work and a parallel effort..."` (lowercase continuation). I did not edit that comment — it's a different file/card's claim, not something this card asked me to fix — but it's now demonstrably false for at least one real document, which is exactly why this card's detector has real work to do rather than being purely defensive.

**Requirement 1** (`lib/sfl/compiler/analysis/chunk_artifact_detector.rb`, new): `ChunkArtifactDetector.detect(clauses, chunk_boundaries)` — pure, dependency-free (duck-types `#text`), returns sorted unique indices of **both** sides of a flagged split (the truncated tail and the continued head — both carry an ambiguous fragment, matching the acceptance text's plural "clauses").

**Requirement 2:** `Types::AnnotationSource` enum extended with `"chunk_artifact"`. `DocumentationAnalyzer#flag_chunk_artifacts` runs post-compile (cross-section boundaries only exist once every section is compiled), restricted to consecutive PDF-chunked sections sharing a `file_id` — markdown sections and cross-file boundaries are structurally excluded from ever producing a `chunk_boundaries` entry, which is how requirement #4's "pure markdown docs never trigger" holds (by construction, not a content check).

**Requirement 3:** Beyond just counting — flagged clauses are excluded from their turn's `avg_tenor`/`avg_modality` (`rebuilt_turn`/`reliable_averages`), not just biased-and-warned-about like fallback/stub currently are. `MarkdownFormatter#data_quality_lines` renders `"**N chunk-boundary artifacts excluded.**"` as a line distinct from the fallback/stub line, both able to coexist.

**Requirement 4 (RSpec):** `chunk_artifact_detector_spec.rb` (7 examples) covers the detector in isolation (mid-sentence flagged, clean boundary not flagged, capitalized-continuation-word edge case, duplicate-index dedup, out-of-range boundaries, empty `chunk_boundaries`). `documentation_analyzer_spec.rb` adds 3 integration examples (mid-sentence split across two stubbed PDF chunks → both clauses `chunk_artifact` + averages recompute to `mean([])` = 0.5; clean PDF boundary → both `llm`; markdown doc with the *same* mid-sentence text never triggers, proving the file-type gate). `markdown_formatter_spec.rb` adds 2 examples for the new Data Quality line. Full suite: 430 examples, 0 failures.

**Live verification (real PDF, real spaCy, real LLM, real Kreuzberg chunking — not mocked):** Ran `bundle exec sfl-analyze documentation longsample.pdf` end-to-end against the 3-chunk PDF described above:
- Markdown report: `## ⚠️ Data Quality` / `**2 chunk-boundary artifacts excluded.**`
- JSON: `annotation_source` tally `{"llm"=>18, "chunk_artifact"=>2}` out of 20 real clauses.
- Turn-level check: both flagged turns' `avg_tenor`/`avg_modality` are computed from their 7 remaining `llm` clauses only — confirmed excluded, not just counted.

This is a stronger verification than the card's own acceptance text asks for (a real document with a real, naturally-occurring split it produced itself, not a constructed 5-page PDF with pre-known breaks).

**Rubocop:** New files (`chunk_artifact_detector.rb` + its spec) are fully clean — zero offenses, since new code gets no pre-existing-debt excuse. For the three modified existing files, diffed against true in-place `git show HEAD` baselines and found three genuinely new offense categories from this card's logic (`pdf_chunk_boundaries`/`rebuilt_turn` in `documentation_analyzer.rb`, `data_quality_warning` in `markdown_formatter.rb`) — all fixed via method extraction (`contiguous_pdf_chunk?`, `turn_clause_count`, `reliable_averages`, `data_quality_lines`/`data_quality_body_lines`) rather than left or disabled. Remaining offenses are pre-existing or marginal incremental growth on already-broken metrics (e.g. `analyze`'s `AbcSize`/`MethodLength` ticking up by the one added line calling the new detection step), consistent with this session's established precedent.