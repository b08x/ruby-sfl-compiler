# Human-in-the-Loop Annotation Review

## Why this track exists

The pipeline already *marks* uncertainty honestly (never-silent provenance: `annotation_source`, `:fuzzy` classification status, reasoning traces with locally computed `derivation_hash`) but offers no way to *act* on it. A report full of fallback 0.5s announces itself — and then nothing can be done except re-running the whole document. HITL review closes that loop: flagged clauses → human decision → persisted correction with provenance.

## Scope (three structural pieces)

1. **Review data model** — where review state lives. Options to weigh: a `review_status`/`reviewed_by`/`reviewed_at` set of columns on `interpersonal_payloads`, vs. a separate `annotation_reviews` table (audit-friendly, preserves the original machine annotation alongside the human override). Human-corrected annotations need their own `annotation_source` value (e.g. `"human"`) — that enum is load-bearing across formatters, coverage stats, and QualityScorer, so extending it touches more than the schema.
2. **Queue + decision surface** — list flagged clauses, show evidence (reasoning trace, premises, fuzzy-match provenance), take accept/re-annotate/reject. `TUI::EvidencePane`'s flagged-clause list is the seed. Buttons via bubblezone if mouse-driven; keybound otherwise.
3. **Single-clause re-annotation path** — `PassTwoEngine#annotate` (the non-batch path) already exists; needs a cache-bypass flag (the resume cache would otherwise return the same bad annotation) and a repository update path (`clause_repository` currently has store/find/delete_by_document, no targeted interpersonal update).

## Constraints / decisions not to relitigate

- **TUI stays PyCall-free.** Re-annotation is Pass 2 only (LLM, no spaCy) so it *could* run in the TUI process — but the safer default is dispatching a job and polling, same as everything else.
- **Surface ownership is undecided**: the React Frontend track's backlog ("Corpus Browser" with annotation_source provenance, dashboard) targets the same review experience in the browser. Both surfaces should consume the same Falcon API endpoints rather than duplicating logic — if review lands in the API layer, TUI and React are both thin clients. Decide before building surface #2.
- **Never overwrite machine output silently.** Whatever the schema, the original machine annotation and the human decision must both survive — this is the project's provenance philosophy extended to humans.

## Non-goals (for now)

- Bulk auto-accept heuristics ("accept all fuzzy above 0.95") — premature until the queue exists and real review volume is known.
- Inter-annotator agreement / multi-reviewer workflows.
