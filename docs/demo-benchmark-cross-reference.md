# Demo / Benchmark Cross-Reference Report

**Date**: 2026-06-22
**Scope**: sfl-compiler repository — all runnable demos, experiments, scripts, and benchmarked code paths.

---

## 1. Inventory

### Demos & Runnable Artifacts (14 total)

| # | Artifact | Type | What It Demonstrates |
|---|----------|------|---------------------|
| 1 | `experiments/01_fca_proof_of_concept.rb` | Experiment | FCA speaker clustering from SFL features |
| 2 | `experiments/02_id3_feature_importance.rb` | Experiment | ID3 feature importance ranking |
| 3 | `experiments/03_theme_rheme_extractor.rb` | Experiment | spaCy Theme/Rheme extraction (failed: 16.7%) |
| 4 | `experiments/04_cohesion_correlation.rb` | Experiment | Cohesion ↔ tenor/modality correlation |
| 5 | `experiments/05_llm_theme_extractor.rb` | Experiment | RubyLLM Theme/Rheme (blocked: gem conflict) |
| 6 | `experiments/06_dspy_theme_extractor.rb` | Experiment | DSPy Theme/Rheme (66.7% accuracy) |
| 7 | `scripts/parse_metacognitive_coprocessor.rb` | Script | NotebookLM batch processing through pipeline |
| 8 | `scripts/process_incidents.rb` | Script | ServiceNow incident processing end-to-end |
| 9 | `scripts/scrub_incidents.rb` | Script | Incident data scrubbing/preprocessing |
| 10 | `scripts/export_callflow.py` | Script | Callflow graph export (Python) |
| 11 | `scripts/export_callflow_directed.py` | Script | Directed callflow graph export (Python) |
| 12 | `exe/sfl-analyze` | CLI | Full CLI: conversation, documentation, context, narrate |
| 13 | `spec/` (28 spec files) | Test suite | Unit tests for all core components |
| 14 | `experiments/README.md` | Doc | Experiment decision tree and usage guide |

### Benchmarked / Instrumented Code Paths

| # | Location | What's Measured | How |
|---|----------|----------------|-----|
| B1 | `pass_two_engine.rb` | Pass-2 batch throughput, latency, defaulted count | Env-tunable (SFL_BATCH_SIZE, SFL_CONCURRENCY), per-batch logging |
| B2 | `pipeline.rb` | End-to-end compile latency, cache hit rate | Wall-clock timing, cache_full_hit/partial_hit counts |
| B3 | `hybrid_retriever.rb` | Retrieval latency, semantic vs keyword counts | Per-query timing, stage counts, filtered count |
| B4 | `conversation_analyzer.rb` | Per-turn elapsed time, annotation source counts | `on_progress` callback with elapsed/clause_count/defaulted |
| B5 | `documentation_analyzer.rb` | Per-section elapsed time, defaulted counts | Same callback pattern as B4 |
| B6 | `process_incidents.rb` | Batch throughput, per-incident summaries | Stdout enumeration of clause_count, distributions |
| B7 | `experiments/RESULTS.md` | Behavioral/accuracy validation (6 experiments) | Markdown narrative with effect sizes |

---

## 2. Consistency Matrix

| Demo/Script | Benchmarked Path | Aligned? | Notes |
|-------------|-----------------|----------|-------|
| 01 FCA | — | ⚠️ GAP | No benchmark for FCA throughput or clustering quality at scale |
| 02 ID3 | — | ⚠️ GAP | No benchmark for ID3 training time or accuracy at scale |
| 03 spaCy Theme/Rheme | — | ❌ N/A | Failed experiment (16.7%) — correctly not productionized |
| 04 Cohesion | — | ⚠️ GAP | No benchmark for cohesion computation cost |
| 05 RubyLLM | — | ❌ N/A | Blocked by gem conflict |
| 06 DSPy Theme/Rheme | B1 (Pass-2 batching) | ✅ YES | Uses same DSPy batching path; LLM cost noted (~$0.05-0.10/conversation) |
| parse_metacognitive | B1, B2, B4 | ✅ YES | Full pipeline; benefits from batch + cache + timing instrumentation |
| process_incidents | B1, B2, B4, B6 | ✅ YES | Closest to a benchmark script; uses all instrumented paths |
| scrub_incidents | — | ⚠️ GAP | Preprocessing only; no SFL pipeline involvement |
| export_callflow | — | ⚠️ GAP | Visualization export; no performance measurement |
| export_callflow_directed | — | ⚠️ GAP | Same as above |
| sfl-analyze CLI | B1–B5 | ✅ YES | All instrumented paths exercised through CLI subcommands |
| spec/ suite | — | ⚠️ PARTIAL | Unit tests correctness, not performance; no benchmark specs |
| experiments/README | B7 | ✅ YES | Documents experiment results |

---

## 3. Discrepancies & Gaps

### Gap 1: Benchmarked but Undemoed — Pass-1 spaCy Throughput

- **What's benchmarked**: Nothing for Pass 1. The benchmark review explicitly notes "Pass 1 spaCy throughput or memory baseline" is NOT benchmarked.
- **What exists**: `pass_one_engine.rb` and `ideational_extractor.rb` are instrumented only by the pipeline wrapper (B2), which measures total latency but can't isolate Pass 1.
- **Impact**: You can't tell if a regression is in spaCy parsing vs. LLM annotation vs. storage.
- **Severity**: Medium. Pass 1 is a single PyCall round-trip per section — likely fast, but unmeasured.

### Gap 2: Benchmarked but Undemoed — Embedding Throughput at Scale

- **What's benchmarked**: Nothing for embedding. The review notes "Embedding throughput / nearest-neighbor latency at scale" is NOT benchmarked.
- **What exists**: `embedding_repository.rb` and the `Embedder` class use RubyLLM → Ollama, but no timing or throughput metrics are captured.
- **Impact**: The `context` subcommand's retrieval quality depends on embeddings, but cost/latency is invisible.
- **Severity**: Low-medium. Only affects the `context` query path.

### Gap 3: Demoed but Unbenchmarkable — FCA & ID3 Experiments

- **What's demoed**: Experiments 01 (FCA) and 02 (ID3) validate theories and are marked "VALIDATED" in RESULTS.md.
- **What's benchmarked**: Neither has throughput, latency, or accuracy-at-scale benchmarks. They run on a single 29-turn fixture.
- **Impact**: If FCA/ID3 are productionized (as RESULTS.md recommends), there are no regression guards.
- **Severity**: Low. These are experimental; productionization hasn't started.

### Gap 4: Demoed but Unbenchmarkable — Cohesion Metrics

- **What's demoed**: Experiment 04 shows strong correlations (repetition ↔ modality: 0.596, conjunction ↔ tenor: 0.569).
- **What's benchmarked**: No performance metrics for cohesion computation.
- **Impact**: RESULTS.md recommends building cohesion metrics in "Phase 1" but there's no baseline to regress against.
- **Severity**: Low. Not yet productionized.

### Gap 5: No End-to-End Latency Regression Suite

- **What exists**: Per-component timing (B1–B5) but no stored baselines or automated comparison.
- **Impact**: You can eyeball logs but can't detect "Pass 2 got 20% slower after this commit" automatically.
- **Severity**: Medium. This is the classic gap between "instrumented" and "benchmarked."

### Gap 6: `scrub_incidents.rb` and `export_callflow*.py` Are Orphans

- **What they do**: Preprocessing and visualization, respectively.
- **Benchmark coverage**: None. Not performance-critical, but also not documented as intentionally excluded.
- **Severity**: Negligible. These are utility scripts.

---

## 4. Recommendations

### High-Value Addition #1: Isolated Pass-1 Benchmark Script

**Gap addressed**: Gap 1 (Pass-1 throughput unmeasured).

Create `scripts/benchmark_pass1.rb` — a throwaway script in the same style as `process_incidents.rb`:

```ruby
# Usage: bundle exec ruby scripts/benchmark_pass1.rb [file_or_dir]
# Measures: spaCy parse time, ideational extraction time, total Pass-1 latency
# Varies: text length (short/medium/long sections)
```

Run it on 3-5 representative inputs of varying size. Store results in `docs/benchmarks/pass1-baseline.md`. This gives you a regression anchor for the one component that's currently a black box.

**Effort**: ~30 lines, no new dependencies. Fits the existing experiment pattern.

### High-Value Addition #2: End-to-End Latency Smoke Test in Spec Suite

**Gap addressed**: Gap 5 (no regression suite).

Add a single spec `spec/sfl/compiler/performance/e2e_latency_spec.rb` that:
1. Compiles a small fixture (the existing `sample.jsonl` — 5 turns).
2. Asserts total pipeline latency is under a generous threshold (e.g., 30 seconds for pass-1-only).
3. Runs with `PASS=1` so no LLM/API dependency.

This is NOT a micro-benchmark — it's a regression smoke test. If someone accidentally adds a O(n²) loop or removes batching, this catches it.

**Effort**: ~20 lines. Uses existing fixtures and `PASS=1` path.

---

## 5. Summary

| Category | Count |
|----------|-------|
| Total demos/artifacts | 14 |
| Total benchmarked paths | 7 |
| Aligned (demo exercises benchmarked path) | 5 |
| Gaps (demo exists but no benchmark) | 4 |
| Orphans (no demo, no benchmark, low value) | 2 |
| Critical unbenchmarked paths | 2 (Pass 1, Embeddings) |

**Bottom line**: The core pipeline (Pass 2 → storage → retrieval → analysis) is well-instrumented and the main demos (sfl-analyze CLI, process_incidents) exercise those paths. The primary gaps are (1) Pass 1 isolation and (2) any form of automated regression detection. The experiments validate theories but aren't performance benchmarks — that's fine as long as they're not productionized without adding baselines first.
