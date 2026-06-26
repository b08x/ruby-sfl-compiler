## Why this track exists

The current `sfl-analyze documentation` pipeline (DocumentationAnalyzer → Pipeline → Pass 1 + Pass 2 → store) produces annotations but has no structured way to challenge its own output quality. When Pass 2 fails on ambiguous paragraphs (especially PDF chunks that split clauses mid-sentence), fallback values (0.5 default) silently bias downstream retrieval and narrative generation.

## GEB mapping

| Agent | Role |
|-------|------|
| **Achilles** | Run initial analysis, surface claims about modality/tenor distribution across document sections |
| **Tortoise** | Challenge: "Is the high modality score real, or an LLM default on ambiguous chunks?" |
| **Crab** | Pin invariants: annotation_source='llm' required for scored clauses; fallback excluded from averages; minimum 30 clauses per document for statistical validity |
| **Crab (constraint)** | Enforce: PDF chunk boundaries that split clauses mid-sentence flagged as structural artifact, not content signal |
| **Genie** | Encode question graph as Gödel number; determine if re-run with different chunking or DSPy params needed |

## Known constraints

- PDF chunking splits clauses at page boundaries — this is a structural artifact, not a content signal
- `annotation_source='fallback'` clauses must be excluded from all aggregate scores (current behavior in markdown formatter is correct, but context synthesizer doesn't filter)
- The `ContextSynthesizer` currently has no awareness of `annotation_source` — it treats fallback clauses as equally reliable as LLM-annotated ones
- Minimum sample size: documents producing <30 clauses should carry a "low confidence" marker in retrieval

## Goal

A documentation analysis pipeline that knows its own limits (Gödel's incompleteness → fail-loud fallback marking, extended to the retrieval layer). Every claim in the report traces back to a clause with known provenance. The retriever surfaces data-quality context alongside retrieved evidence.
