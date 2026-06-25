# Design Decisions & Rationale

Extracted from inline comments (`# NOTE:`, `# WHY:`, `# HACK:`, `# TODO:`) and design documents via graphify. Modality reflects extraction confidence.

---

## Parallel Turn Processing with Gush

**Extracted from**: `lib/sfl/compiler/jobs/compile_turn_job.rb`, `lib/sfl/compiler/cli.rb` *(INFERRED)*

**Decision**: Process large conversation turns in parallel via Gush/Sidekiq using per-turn jobs.

**Rationale**: Pass 1 uses spaCy through PyCall, Pass 2 uses the Ruby LLM. Both paths can contend on the GIL and trigger GC deadlocks when run in threads inside the same Ruby process. Forking each turn into its own `CompileTurnJob` isolates Python interpreter state, avoids the GIL deadlock, and keeps `--live` semantics simple for users.

**Trade-offs**: Requires Redis; adds operational surface (worker processes); failure reporting moves from inline exceptions to job-level `DEFAULTED` counts and per-turn warnings.

**Confidence**: INFERRED from `CompileTurnJob` implementation, the `--live` flag wiring, and AGENTS.md note on PyCall GC deadlock.

---

## Langfuse Reachability Pre-Flight

**Extracted from**: `lib/sfl/compiler/langfuse_reachability.rb`, `lib/sfl/compiler/bootstrap.rb` *(INFERRED)*

**Decision**: Verify the Langfuse endpoint is reachable before enabling OpenTelemetry tracing.

**Rationale**: Tracing failures manifest as noisy warning spam or broken spans that are hard to distinguish from analysis failures. A fast pre-flight check lets the CLI fail gracefully: skip tracing silently when keys are unset, prompt interactively when the endpoint is down, and continue silently in non-TTY mode. This preserves the "works out of the box" experience while avoiding surprise observability outages.

**Trade-offs**: Adds one network round-trip at startup; interactive mode now blocks on user input if Langfuse is unreachable.

**Confidence**: INFERRED from `LangfuseReachability` class and `Bootstrap` usage.

---

## Cross-Document Graph Querying

**Extracted from**: `lib/sfl/compiler/cross_document_graph.rb` *(INFERRED)*

**Decision**: Build a query-time entity/clause graph over stored documents instead of synthesizing each document independently.

**Rationale**: `context` answers from a single blended result set. Questions that compare documents — "how does the API guide differ from the web guide?" — benefit from explicit document-level nodes and relationships. The graph resolves entities across documents, ranks evidence with the same RRF scorer as `HybridRetriever`, and then synthesizes an answer.

**Trade-offs**: More complex than flat retrieval; currently library-only, no dedicated CLI subcommand.

**Confidence**: INFERRED from `CrossDocumentGraph` implementation.

---

## Sprint Workflow for Batch Runs

**Extracted from**: `lib/sfl/compiler/workflows/sprint_workflow.rb` *(INFERRED)*

**Decision**: Wrap batch analysis in a workflow object that collects reports and failures rather than failing fast on the first bad file.

**Rationale**: Operations teams often need to process dozens of conversations produced by cron or ingestion. Failing fast on one malformed JSONL aborts the whole batch. `SprintWorkflow.run` processes each path, captures per-item errors in `result.failures`, and returns a summary useful for downstream dashboards.

**Trade-offs**: Callers must inspect `result.failures` explicitly; a fully successful run still returns a structured result object rather than a plain array.

**Confidence**: INFERRED from `SprintWorkflow` implementation.

---

## Circuit Breaker Implementation

**Extracted from**: `lib/sfl/compiler/pass_two/pass_two_engine.rb:173` *(EXTRACTED)*

**Decision**: Use placeholder CircuitBreaker::CircuitHandler in transparent_callable

**Rationale**: Temporary implementation **enables** basic circuit breaker functionality **while** Pass 2 is not yet in active production use. Full CircuitBreaker::CircuitHandler **will be** implemented once failure rates are monitored and patterns are understood.

**Trade-offs**: Current implementation is simpler but less configurable; production monitoring is needed to tune thresholds.

**Confidence**: EXTRACTED from TODO comment in source code.

---

## Metafunction Separation

**Extracted from**: `lib/sfl/compiler/pass_two/pass_two_engine.rb:426` *(EXTRACTED)*

**Decision**: Processes belong to Ideational metafunction are handled in Pass 1; Interpersonal and Textual in Pass 2

**Rationale**: **Separates** deterministic syntactic parsing (spaCy) **from** LLM-dependent semantic annotation. This **enables** independent testing, caching, and optimization of each pass.

**Trade-offs**: Requires coordination between passes; ideational features are not available during Pass 2.

**Confidence**: EXTRACTED from NOTE comment in SFLSignature definition.

---

## Two-Pass Architecture

**Extracted from**: Architecture analysis *(EXTRACTED)*

**Decision**: Split processing into Pass 1 (spaCy syntactic) and Pass 2 (LLM semantic)

**Rationale**: Syntax trees **are** deterministic and fast; interpersonal features **require** LLM inference. Separation **enables** caching, resume, and independent testing of each stage.

**Trade-offs**: Added complexity in pipeline coordination; need to handle partial failures gracefully.

**Confidence**: EXTRACTED from code structure and PassTwoEngine/PassOneEngine separation.

---

## pgvector Integration

**Extracted from**: `lib/sfl/compiler/storage/embedding_repository.rb` *(EXTRACTED)*

**Decision**: Use pgvector for embedding storage and retrieval

**Rationale**: **Enables** efficient nearest-neighbor search without external vector database. Native PostgreSQL integration **simplifies** infrastructure and **leverages** existing pgvector indexing.

**Trade-offs**: Tight coupling to PostgreSQL; pgvector extension must be installed; less flexible than dedicated vector databases.

**Confidence**: EXTRACTED from EmbeddingRepository using Pgvector.encode() for all vector operations.

---

## Pipeline Caching

**Extracted from**: `lib/sfl/compiler/storage/pipeline_cache.rb` *(EXTRACTED)*

**Decision**: Implement disk-based caching of intermediate results with SHA256 keys

**Rationale**: Clauses with identical text at the same document position **produce** identical annotations. Cache **prevents** redundant LLM calls on resume **and** **reduces** processing time significantly.

**Trade-offs**: Disk I/O overhead; cache invalidation complexity when prompts or models change; manual clearing required for stale entries.

**Confidence**: EXTRACTED from PipelineCache implementation and cache_key design.

---

## Cache Key Design

**Extracted from**: `lib/sfl/compiler/storage/pipeline_cache.rb:119-127` *(EXTRACTED)*

**Decision**: Include sentence_index in cache key: SHA256(document_id + sentence_index + clause_text)

**Rationale**: **Prevents** cache collisions **when** identical boilerplate text (e.g., repeated headers) **appears** at different positions. Previous implementation (document_id + clause_text only) **caused** both clauses to report the cached entry's single external_id, **resulting in** duplicate-key violation when both get stored.

**Trade-offs**: Cache entries **are** less reusable across documents with identical text at different positions.

**Confidence**: EXTRACTED from cache_key implementation and commit message.

---

## Theme Type Normalization

**Extracted from**: `lib/sfl/compiler/pass_two/pass_two_engine.rb:148-170` *(EXTRACTED)*

**Decision**: Implement normalize_theme_type() with validation against allowed enum

**Rationale**: LLM output for theme_type **varies** across runs and models. Normalization **ensures** consistent values **despite** LLM variability by handling:
- Typos (e.g., "topual" → "topical")
- Compound types (e.g., "textual + topical" → "textual")
- Legacy values (e.g., "topical_unmarked" → "unmarked")
- Nil/empty inputs (→ "unmarked")

**Trade-offs**: Some semantic nuance **may be lost** when compound types are reduced to single values.

**Confidence**: EXTRACTED from normalize_theme_type implementation and test suite.

---

## Embedder Extraction

**Extracted from**: `lib/sfl/compiler/retrieval/` *(EXTRACTED)*

**Decision**: Move Embedder class from hybrid_retriever.rb to separate embedder.rb file

**Rationale**: **Improves** code organization **and** **enables** reuse of embedding capabilities. Embedder **is** now a standalone component **that can be** used independently of retrieval logic.

**Trade-offs**: Additional file; need to update requires in dependent files.

**Confidence**: EXTRACTED from recent commit moving Embedder to separate file.

---

## Ollama Base URL Configuration

**Extracted from**: `lib/sfl/compiler/retrieval/embedder.rb:44-51` *(EXTRACTED)*

**Decision**: Ensure Ollama base URL has /v1 suffix for OpenAI-compatible endpoints

**Rationale**: RubyLLM::Providers::Ollama subclasses the OpenAI provider and only speaks OpenAI-style routes. Without /v1 suffix, requests land on bare /embeddings instead of /v1/embeddings, which Ollama doesn't route.

**Trade-offs**: Additional URL manipulation logic.

**Confidence**: EXTRACTED from openai_compatible_base method implementation.

---

## Hybrid Retrieval (RRF)

**Extracted from**: `lib/sfl/compiler/retrieval/hybrid_retriever.rb` *(EXTRACTED)*

**Decision**: Combine keyword and semantic search using Reciprocal Rank Fusion

**Rationale**: Keyword search **excels** at exact matches; semantic search **captures** conceptual similarity. RRF **typically produces** better results than either alone **by** combining ranked results from both approaches.

**Trade-offs**: Increased query complexity; need to tune fusion parameters; more resource-intensive.

**Confidence**: EXTRACTED from HybridRetriever implementation using RRF.

---

## Circumstances Serialization

**Extracted from**: `lib/sfl/compiler/storage/pipeline_cache.rb:184-187` *(EXTRACTED)*

**Decision**: Change circumstances from mapping reconstruct_participant to raw array

**Rationale**: reconstruct_ideational **expected** Participant structure (with text, role, head) **but** circumstances **are** simpler arrays. Mapping reconstruct_participant **caused** errors when deserializing.

**Trade-offs**: Circumstances **lose** the participant structure **but** this matches the actual data model where circumstances don't have role/head fields.

**Confidence**: EXTRACTED from pipeline_cache.rb commit fixing serialization.

---

## Fallback Values in Data Quality

**Extracted from**: `lib/sfl/compiler/analysis/conversation_analyzer.rb` *(INFERRED)*

**Decision**: Track and report clauses with fallback/stub interpersonal values

**Rationale**: LLM annotations **may** produce incomplete or invalid values. Data quality section **enables** users to assess result reliability **and** identify problematic input clauses.

**Trade-offs**: Additional processing overhead; quality metrics **add** complexity to output structure.

**Confidence**: INFERRED from data quality section in output formatters.

---

## Output Directory Structure

**Extracted from**: `.claude/skills/sfl-analyze/SKILL.md` *(EXTRACTED)*

**Decision**: Use `./output/latest` as default output directory

**Rationale**: **Provides** consistent location **for** analysis outputs **while** allowing date-based organization for multiple runs. Previous default was `./sfl_output`.

**Trade-offs**: None significant; directory is configurable via --output-dir flag.

**Confidence**: EXTRACTED from SKILL.md documentation update.

---

## Ruby Pragmatist Design Philosophy

The sfl-compiler's design philosophy **balances** precision with pragmatism:

- **Precision**: Two-pass architecture **separates** what can be deterministic (syntax) from what requires interpretation (semantics)
- **Pragmatism**: Caching, circuit breakers, and fallbacks **ensure** the system works even when LLM calls fail
- **Honesty**: Data quality tracking **acknowledges** that LLM output is not always perfect
- **Flexibility**: Configurable timeouts, models, and endpoints **allow** adaptation to different environments

This philosophy **results in** a system that **delivers** high-quality linguistic analysis **when** everything works perfectly **while** still **providing** useful results **when** things go wrong.
