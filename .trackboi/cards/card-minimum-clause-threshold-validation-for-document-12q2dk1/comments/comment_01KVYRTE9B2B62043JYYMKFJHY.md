---
id: "comment_01KVYRTE9B2B62043JYYMKFJHY"
cardId: "card-minimum-clause-threshold-validation-for-document-12q2dk1"
createdAt: "2026-06-25T06:52:31.403Z"
updatedAt: "2026-06-25T06:52:31.403Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done. One deviation from the card's literal requirement #4 — documented below.**

**Requirement 1** (`lib/sfl/compiler/analysis/documentation_analyzer.rb`): Added `MIN_CLAUSE_THRESHOLD = 30`. `#analyze` sums `turns.sum { |t| t.clauses.size }`, sets `metadata[:clause_count]`/`[:low_confidence]`/`[:low_confidence_threshold]` (the threshold is also stored in metadata, beyond the card's literal ask, so the formatter/narrative don't hardcode the magic number `30` redundantly).

**Deviation on requirement 4 (0-clause case):** the card says "errors gracefully with a message about insufficient data" without specifying *how* — I implemented this as a raised `SFL::Compiler::InsufficientDataError` (new error class added to the hierarchy in `lib/sfl/compiler.rb`), not a returned/logged message. Rationale: this codebase's established pattern (see `NarrativeError`, `TopicModelerError`, `QuestionGraphError`) is to raise typed errors for "this can't proceed" cases rather than degrade into a placeholder report — and a 0-clause report would otherwise silently render as all-0.5-defaults (`Aggregations#mean` returns 0.5 for empty arrays), which is exactly the "false measurement disguised as data" problem this track exists to prevent. "Errors gracefully" is satisfied via a clear message (`"<path> produced 0 clauses across N section(s) — insufficient data to analyze..."`), not a non-raising return value. Flagging this since it's a real interpretive choice, not what's literally written.

**Requirement 2** (`lib/sfl/compiler/formatters/markdown_formatter.rb`): `low_confidence_banner` renders above the existing `data_quality_warning`, using `> ##` (blockquoted H2) for visual prominence vs. the plain `### ⚠️ Data Quality` section — deliberately distinct severity treatment per the card's "similar but more prominent" instruction.

**Requirement 3** (`lib/sfl/compiler/analysis/narrative_generator.rb`): Two layers, not one — (a) `Digest#to_text` opens with an explicit `== LOW CONFIDENCE WARNING ==` block (verified live, see below) so the LLM sees it before any other content, and (b) `NarrativeSignature`'s description was extended to instruct the model to honor it in `data_quality`/`takeaways`. Note: since `metadata` is forwarded wholesale into the digest already, the raw flag would have reached the LLM even without this — the explicit block exists to make the caveat *load-bearing* rather than buried among dozens of other metadata lines.

**Requirement 4 (RSpec):** Added exactly the three named scenarios (29/31/0 clauses) to `documentation_analyzer_spec.rb`, plus banner-presence/absence specs to `markdown_formatter_spec.rb` and digest-warning specs to `narrative_generator_spec.rb`. Full suite: 418 examples, 0 failures.

**Live verification (real pipeline + real LLM, not mocked):** Ran `bundle exec sfl-analyze documentation short_doc.md` against a real one-line markdown file (1 real clause via spaCy + real LLM Pass 2):
- Markdown report: `> ## 🚨 LOW CONFIDENCE: 1 clauses (minimum 30 recommended)`.
- JSON: `{"clause_count"=>1, "low_confidence"=>true, "low_confidence_threshold"=>30}`.
- `--narrative`: real LLM-generated narrative's Data Quality section states *"This analysis rests on a single clause against a recommended minimum of 30. The LOW CONFIDENCE WARNING is explicit: findings are provisional and should not be generalized."* — and Takeaways independently reiterates n=1 caveats. Matches the acceptance criteria's "narrative explicitly states the analysis is based on a small sample."

**Rubocop:** Diffed every touched file against its true in-place `git show HEAD` baseline (not a `/tmp` copy — confirmed again this session that approach silently uses default cop config instead of `.rubocop.yml`). Found one file (`narrative_generator.rb`) where an earlier combined-file rubocop invocation truncated cop-name prefixes and made it look offense-free; re-ran it in isolation to get the real baseline. Net result: zero new offense categories anywhere — only the expected incremental growth (`ClassLength`/`AbcSize`/`MethodLength` ticking up by exactly the lines added) on methods/classes already over their limits before this card, consistent with this session's established precedent for unavoidable minimal-necessary growth.