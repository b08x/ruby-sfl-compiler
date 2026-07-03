# Rolling Synthesis Validation

**Date**: 2026-07-03
**Goal**: Integration-validate Rolling Synthesis (CognitiveGas → IntermediateGenieJob → Axiomatic summary) against a real document, per the card's three questions.
**Method**: Real Pass 1 + Pass 2 compile + Genie compression against a real PDF, through the live Falcon-adjacent pipeline components (no mocks), against a real Postgres + a real DSPy/OpenRouter LLM.
**Document**: [Bavali & Sadighi, "Chomsky's UG and Halliday's SFL"](../experiments/) — 59 sections, 7,434 words, extracted via `PdfLoader`/Kreuzberg from `~/Notebook/assets/pdf/`.

---

## Summary

| Question | Result |
|---|---|
| (1) Process type distribution preserved within 10pp | ✅ **PASS** — 0.0pp delta (exact) |
| (2) Stance filter hit-rate equivalence (raw vs. summarized) | ❌ **FAIL** — 13–26pp deltas |
| (3) Context window stays bounded, not proportional to doc length | ✅ **PASS** — fixed at 15 clauses/call |
| Bug found: CognitiveGas → IntermediateGenieJob auto-wiring | 🐛 **BROKEN** — ID-namespace mismatch, always compresses zero clauses |
| Bug found: DSPy/OpenRouter calls hang past all configured timeouts | 🐛 **CONFIRMED** — ~44% of LLM calls needed OS-level `timeout` to recover |

Two genuine production bugs surfaced by this validation are more consequential than the three numeric questions it set out to answer — see below.

---

## Setup

`Pipeline` doesn't expose a way to inject `PassTwoEngine`'s `circuit_breaker:`/`on_gas_exhausted:`, so this ran Pass 1 (`PassOneEngine` + `IdeationalExtractor`) and Pass 2 (`PassTwoEngine`) directly, storing each `AnnotatedClause` via `ClauseRepository#store` as it completed. 79 clauses were compiled and stored (26 of 59 sections completed within a 60s-per-section budget — see Bug 2).

```
material:    51 (64.6%)
relational:  24 (30.4%)
verbal:       3 ( 3.8%)
mental:       1 ( 1.3%)
```

Clauses were then split into fixed 15-clause windows (5 full + 1 partial of 4) and each window compressed via `IntermediateGenieJob` directly — not through `CognitiveGas`'s automatic trigger, because that trigger is broken (Bug 1). All 6 windows compressed successfully into `axiomatic_summaries` rows.

---

## (1) Process type distribution — PASS

`IntermediateGenieJob#build_aggregates` computes `process_type_distribution` deterministically from the windowed rows (not from the LLM's prose), so reconstructing the whole-document distribution as a `clause_count`-weighted average across windows is an exact partition — and it landed exact:

```
material:    raw=64.6%  summary=64.6%  delta=0.0pp
verbal:      raw=3.8%   summary=3.8%   delta=0.0pp
relational:  raw=30.4%  summary=30.4%  delta=0.0pp
mental:      raw=1.3%   summary=1.3%   delta=0.0pp
```

**PASS** — well within the 10-point tolerance. This validates that the aggregation math survives windowed compression; it does *not* validate the LLM-generated summary prose, which was not checked against the source for factual fidelity (out of scope for this pass).

## (2) Stance filter hit-rate equivalence — FAIL

Comparing "% of raw clauses individually passing a `min_modality`/`min_tenor` threshold" against "% of *summary windows* whose *averaged* `avg_modality`/`avg_tenor` passes the same threshold":

```
min_modality>=0.5, min_tenor>=0.0: raw=86.1% (68/79)  summary=100.0% (6/6)  delta=13.9pp
min_modality>=0.0, min_tenor>=0.5: raw=92.4% (73/79)  summary=66.7% (4/6)  delta=25.7pp
min_modality>=0.5, min_tenor>=0.5: raw=83.5% (66/79)  summary=66.7% (4/6)  delta=16.9pp
min_modality>=0.7, min_tenor>=0.0: raw=79.7% (63/79)  summary=66.7% (4/6)  delta=13.1pp
```

**FAIL** — deltas of 13–26 percentage points, well outside any reasonable equivalence tolerance. This is not noise; it's structural. Averaging tenor/modality across a 15-clause window smooths out individual clauses that would pass or fail a threshold on their own — a window containing a few strongly-hedged clauses and many confident ones can average *above* a threshold that most of its individual clauses fall *below*, or vice versa. With only 6 coarse windows standing in for 79 individual data points, this effect is large. **Stance-filtered retrieval over Axiomatic summaries is not a safe substitute for stance-filtered retrieval over raw clauses** — a caller wanting "clauses with high modality" gets a materially different result set querying summaries vs. querying `HybridRetriever` directly. If Rolling Synthesis summaries are ever meant to back filtered retrieval (not just compression for context-budget purposes), this needs either per-clause stance metadata preserved in the summary record, or a documented accuracy caveat.

## (3) Context window boundedness — PASS

```
window 0: 15 clauses    window 3: 15 clauses
window 1: 15 clauses    window 4: 15 clauses
window 2: 15 clauses    window 5:  4 clauses (final partial)
```

Each `IntermediateGenieJob` call's evidence prompt is built strictly from its own window (`format_evidence(rows)` in `intermediate_genie_job.rb`) — never from a growing history. Window size stayed fixed at 15 (default `CHUNK_SIZE`) regardless of how far into the document that window fell. **PASS** — the per-call context window does not grow proportionally with document length, by construction.

---

## Bug 1: CognitiveGas → IntermediateGenieJob auto-wiring is non-functional

**Confirmed via `repro_gas_exhaustion_bug.rb`.** `PassTwoEngine#trigger_rolling_synthesis` fires `on_gas_exhausted` with `chunk.map { |e| e[:clause].id }` — `SyntacticClause#id`, assigned by `PassOneEngine` at Pass 1 (`pass_one_engine.rb:65`, `SecureRandom.uuid`). But `IntermediateGenieJob#perform` looks clauses up via `ClauseRepository#find(id)`, which queries `clauses.external_id` — populated from `AnnotatedClause#id`, assigned *independently* by `PassTwoEngine#annotated_clause` (`pass_two_engine.rb:465`, a **second, unrelated** `SecureRandom.uuid`). These are two different random UUIDs for the same logical clause, in two different ID namespaces, and nothing anywhere maps one to the other.

Live repro output:

```
Pass-1 SyntacticClause ids: ["a5561825-...", "d5aec6e3-...", "6706e0c5-..."]
on_gas_exhausted fired with ids: ["a5561825-...", "d5aec6e3-...", "6706e0c5-..."]
AnnotatedClause ids (what actually lands in `clauses.external_id`): ["8abf2923-...", "219cd89a-...", "859a74d9-..."]
IDs match: false
IntermediateGenieJob output: {..., summary_text: "No evidence provided for analysis.",
  core_claim: "No core claim can be derived from the given data.",
  process_type_distribution: {}, avg_tenor: 0.5, avg_modality: 0.5,
  mood_distribution: {}, key_participants: [], clause_count: 0}
```

There's also a second, independent timing problem even if the IDs matched: `trigger_rolling_synthesis` fires for the chunk *about to be* Pass-2-annotated, before that chunk has been annotated or stored anywhere — so even a perfectly-matched ID would find nothing yet. The semantically correct behavior ("compress the clauses processed *so far*") needs `on_gas_exhausted` to receive already-completed, already-stored clause IDs from *prior* chunks, which requires threading a completed-results accumulator through `annotate_batch`'s (partly concurrent) chunk loop — a real design change, not a one-line fix. Filed as a follow-up card rather than attempted here, given the blast radius and design decisions involved.

**Impact**: every real CognitiveGas-triggered Rolling Synthesis cycle in production would build an Axiomatic summary from zero clauses — a silent, permanently-degenerate summary ("No evidence provided for analysis.") every time the budget trips. This has presumably never fired in production, since nothing currently injects `CognitiveGas`/`on_gas_exhausted` into a real `PassTwoEngine` outside tests (per `CLAUDE.md` gotcha #2).

## Bug 2: DSPy/OpenRouter LLM calls hang past every configured timeout

Multiple full-document runs (`concurrency: 4`, then `concurrency: 1`) stalled indefinitely — 630s+ elapsed with zero forward progress, `ss -tnp` showing sockets to OpenRouter's Cloudflare front (`104.18.2.115:443`, `104.18.3.115:443`) sitting in `CLOSE-WAIT`/`ESTABLISHED` with large **unread** `Recv-Q` backlogs (up to 15,901 bytes). This is exactly the failure class `pass_two_engine.rb`'s own `DEFAULT_CHUNK_TIMEOUT` comment already anticipated ("response bytes sitting unread in the socket while the async reactor deadlocks on a mutex") — but `chunk_timeout` (120s) × `batch_attempts` (3) did not actually bound it in practice; both runs sat stuck for 10+ minutes with no recovery, well past the documented worst case.

**Workaround used for this validation** (not a production fix): isolate each unit of work — one PDF section, one compression window — in its own OS process via `timeout 60 bundle exec ruby ...` in a driver loop (`process_one_pdf_section.rb`, `compress_one_window.rb`), so a hang in one process can be killed from outside without losing prior progress. Only 26 of 59 sections (44%) completed within the 60s-per-process budget; the rest were killed and skipped. This is consistent with the codebase's own precedent for a different problem (isolating spaCy/PyCall into separate Sidekiq processes because in-process concurrency wasn't safe, `CLAUDE.md` gotcha #12) — the same isolation strategy recovers here too, for an unrelated root cause.

**Impact**: this is a standing reliability risk for *any* long Pass 2 run (`documentation`/`conversation` CLI subcommands, Gush `CompileTurnJob`/`CompileSectionJob` workflows), not specific to Rolling Synthesis — it happened to surface here because this was the first time this session ran a long, many-chunk document through Pass 2 sequentially and watched it closely enough to notice the hang rather than just seeing an eventual timeout warning in a log. Worth a dedicated investigation into why `Timeout.timeout` isn't interrupting these calls (a known class of Ruby issue with blocking native reads not honoring `Timeout` — possibly needs a lower-level socket-level timeout on the HTTP client Faraday/DSPy::LM uses, not an application-level `Timeout.timeout` wrapper).

---

## Scripts

- `repro_gas_exhaustion_bug.rb` — minimal repro of Bug 1
- `process_one_pdf_section.rb` — per-section Pass 1+2 worker (run via a `timeout N` driver loop, see Bug 2)
- `compress_one_window.rb` — per-window `IntermediateGenieJob` worker (same reason)
- `rolling_synthesis_validation.rb` — the original single-process attempt; kept as-is since it documents the concurrency-related hang finding, but superseded in practice by the two per-process worker scripts above once Bug 2 made a single long-running process unreliable
