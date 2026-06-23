# Codebase Benchmark & Performance Review

Repository: `sfl-compiler`  
Task focus: benchmark directories/files, performance test patterns, metrics collected, tooling used, and result storage.

## 1. Overall Finding

This codebase does **not** contain a dedicated benchmarking suite, benchmark directory, or benchmark-result archive with reported baselines. There are `experiments/` scripts and structured logging/timing in production code, but no harness such as Benchmark/Rails::Benchmark, `pytest-benchmark`, or a comparable Ruby equivalent.

`hyperframes.json` is the only repo file suggesting a benchmark role, but it is untracked media output, not a benchmark definition.

## 2. Files Examined

- `Gemfile` — confirms no benchmark/testing framework beyond RSpec.
- `Rakefile` — test/DB tasks only; no benchmark task.
- `lib/sfl/compiler/pass_two/pass_two_engine.rb` — tunable throughput controls and timing/metric logging.
- `lib/sfl/compiler/pipeline.rb` — total compile latency and cache hit result paths.
- `lib/sfl/compiler/analysis/conversation_analyzer.rb` — turn-level timing and annotation source counts.
- `lib/sfl/compiler/analysis/documentation_analyzer.rb` — section-level timing.
- `lib/sfl/compiler/retrieval/hybrid_retriever.rb` — retrieval latency metrics.
- `scripts/process_incidents.rb` — end-to-end batch throughput script with per-incident summaries.
- `experiments/RESULTS.md`, `experiments/01_*` through `experiments/06_*` — ad-hoc validation scripts.
- `scripts/export_callflow_directed.py` — visualization export; not benchmark in itself.
- `spec/` — unit tests only; no benchmark specs and no integration benchmark fixtures.

## 3. Performance-Test Patterns Discovered

### 3.1 Instrumented Pass-2 Batching Throughput  
- Location: `lib/sfl/compiler/pass_two/pass_two_engine.rb:22-32`, `:51`, `:75-84`, `:220-241`  
- Pattern: tunable batch size / concurrency with per-batch latency measurement.  
- Controls: `SFL_BATCH_SIZE` default `12`, `SFL_CONCURRENCY` default `4`, `SFL_CHUNK_TIMEOUT` default `180` seconds.  
- Metrics emitted: `latency_ms`, clause count, chunk count, defaulted count, correlation `id`.  
- Goal: reduce total round-trip count and overlap I/O-bound LLM calls.

### 3.2 Full-Pipeline Latency Measurement  
- Location: `lib/sfl/compiler/pipeline.rb:44-57`, `:103-117`  
- Pattern: wall-clock measurement from Pass 1 start through storage/embedding end.  
- Metrics emitted: `text_length`, `clause_count`, stored flag, embedded flag, resume flag, and overall `latency_ms`.

### 3.3 Cache Performance  
- Location: `lib/sfl/compiler/pipeline.rb:164-205`, `spec/sfl/compiler/pipeline_cache_spec.rb`  
- Pattern: measure `cache_full_hit`, `cache_partial_hit`, cached count vs uncached count to estimate LLM-call savings.  
- Source-of-truth code path: `Pipeline#compile_with_cache` returning cached `AnnotatedClause[]` and logging counts.

### 3.4 Retrieval Latency  
- Location: `lib/sfl/compiler/retrieval/hybrid_retriever.rb:36-78`, `:80-140`, `:164-199`  
- Pattern: measure semantic vs keyword stage results and final filtered count.  
- Metrics emitted: `semantic_count`, `keyword_count`, `merged_count`, `filtered_count`, `latency_ms`, correlated query snippet.

### 3.5 ConversationTurn / Documentation Turn Annotations Timing  
- Location: `lib/sfl/compiler/analysis/conversation_analyzer.rb:27-56`, `:125-191`  
- Location: `lib/sfl/compiler/analysis/documentation_analyzer.rb:39-56`, `:214-222`  
- Pattern: per-turn/per-section elapsed time and `defaulted` counts reported via callback.  
- This is the strongest performance observability for end-to-end batch analysis.

### 3.6 Incident Processing Script  
- Location: `scripts/process_incidents.rb`  
- Pattern: shell/ruby script processing a folder of incident files.  
- Outputs per incident: `clause_count`, process/mood modality distributions, source provenance counts.  
- This is the closest thing to a repro/performance script, but it is operational and not a benchmark with baselines.

## 4. Experiment Suite

- Location: `experiments/01_fca_proof_of_concept.rb`, `02_id3_feature_importance.rb`, `03_theme_rheme_extractor.rb`, `04_cohesion_correlation.rb`, `05_llm_theme_extractor.rb`, `06_dspy_theme_extractor.rb`  
- Style: throwaway Ruby scripts on a fixed fixture conversation.  
- `RESULTS.md` reports hypothesis validation status and noted effect sizes.  
- These are behavioral/accuracy validations, not throughput or latency benchmarks.  
- Result storage: markdown narrative (`experiments/RESULTS.md`), not machine-machine consumable baselines.

## 5. What Is NOT Being Benchmarked

No code was found for:
- Pass 1 spaCy throughput or memory baseline.
- End-to-end latency regressions for `context` queries with filters.
- Embedding throughput / nearest-neighbor latency at scale.
- Load or concurrency testing of parser + retriever + LLM paths.
- Automated comparison across `SFL_BATCH_SIZE` / `SFL_CONCURRENCY`.

## 6. Where Results Are Stored

- Structured operational metrics: Journald via `Journald::Logger` under service names `sfl-compiler-pass-two`, `sfl-compiler-pipeline`, `sfl-compiler-retriever`.
- Callback-based Python/Ruby caller observability: analyzer `on_progress` hashes with `elapsed`, `clause_count`, `defaulted`.
- Incidents: stdout only during script execution; no artifact files written.
- Experiments: human-readable markdown (`experiments/RESULTS.md`).

## 8. Source References

- `docs/status/BACKLOG_FIXES.md` notes `mean` is duplicated and analyzer helpers are duplicated, implying missing shared timing/profile helpers.
- `Gemfile` confirms only RSpec/RuboCop in `:development, :test`; no benchmark gem present.
- `spec/sfl/compiler/pipeline_cache_spec.rb` implies cache coverage exists, but no comparison baselines are stored.

## 9. Conclusion

This codebase measures performance in-flight but lacks a stored benchmark dataset, harness, or regression suite. The meaningful performance behavior is:
1. batching throughput on the Pass-2 LLM path env-driven,
2. Pipeline end-to-end timing,
3. Retrieval scoring/filtering latency,
4. analyzer turn/section elapsed times,
5. cache-hit and source-distribution logging,
6. incident script throughput enumerations.
