# Modular Integration Guide: SFL Compiler as RAG Middleware

**Status:** Practical Engineering Guide
**Parent:** [README — The Core Hypothesis](../../README.md#the-core-hypothesis-stance-filtered-rag-safe-rag)

---

## Premise

You already have a RAG pipeline. It chunks documents, embeds them, stores
vectors in a database, retrieves by similarity, and feeds the results to an
LLM. It works. You do not want to rewrite it.

You do not have to. The SFL Compiler is designed to act as **modular
middleware** — two interceptors that plug into your existing pipeline at the
ingestion and retrieval stages, enriching your data with SFL metadata and
filtering retrieval results by rhetorical stance. Your chunking strategy,
your embedding model, your vector database, and your LLM all stay where they
are.

This guide shows exactly where the SFL modules plug in, what they do, and
what stays unchanged.

---

## The Pipeline Comparison

```
STANDARD RAG
──────────────────────────────────────────────────────────────────

  Documents ──► Chunk ──► Embed ──► Vector Store
                                        │
                                        │  (retrieve by similarity)
                                        ▼
                                    Query ──► LLM ──► Answer


SFL-ENHANCED RAG
──────────────────────────────────────────────────────────────────

  Documents ──► Chunk ──► SFL ANNOTATE ──► Embed ──► Vector Store
                    │         │                           │
                    │         │                           │
                    │    [Pass 1: spaCy]            (SFL metadata
                    │    [Pass 2: LLM]              stored alongside
                    │         │                     vectors)
                    │         ▼
                    │    SFL Payload               Query ──► SFL ROUTER
                    │    {mood, tenor,                 │
                    │     modality,                    │ (extract stance
                    │     process_type}                 │  filters from
                    │         │                         │  query intent)
                    │         │                         ▼
                    └─────────┴──────────► RRF + Scalar Filters
                                              │
                                              │  (semantic + keyword
                                              │   merge, then filter
                                              │   by mood/modality/
                                              │   tenor)
                                              ▼
                                          LLM ──► Answer
                                          (context window:
                                           filtered, objective)
```

Two insertion points. Everything between them is your existing stack. The SFL
Compiler does not replace any component — it enriches data going in and
filters results coming out.

---

## Part 1: The Ingestion Middleware

### What You Keep

Your chunking strategy stays exactly as it is. Whether you chunk by fixed
token count, by heading, by semantic boundaries, or by paragraph — the SFL
Compiler does not care how chunks are produced. It processes whatever text
you hand it.

Your embedding model stays. The SFL Compiler does not replace OpenAI ADA,
Cohere, Voyage, or any other embedding model. It runs *before* the embedding
step, enriching the chunk with metadata. The chunk is then embedded and
stored exactly as your pipeline already does.

Your vector database stays. The SFL metadata is stored in a separate payload
table (see below), not fused into the vector index. Your pgvector,
Pinecone, Weaviate, or Qdrant index operates on the same vectors it always
has.

### The Hook: Two-Pass Annotation Before Embedding

Right before the chunk goes to the embedding model, it passes through the
SFL Compiler's Two-Pass Engine. This is the ingestion middleware — a
pre-embedding enrichment step that annotates every clause in the chunk with
SFL metadata.

```
Chunk ──► Pass 1 (spaCy) ──► Pass 2 (LLM) ──► SFL Payload ──► Embed ──► Store
         Syntactic          Interpersonal     {mood,           (your model)
         extraction         annotation        tenor,
         (rule-based,       (batched,         modality,        (your vector DB)
         ~50ms/clause)      ~2s/clause)       process_type}
```

**Pass 1** (see `lib/sfl/compiler/pass_one/pass_one_engine.rb`) runs spaCy
through PyCall — tokenization, POS tagging, dependency parsing, sentence
segmentation. Then the `IdeationalExtractor` (rule-based, no LLM) classifies
each clause's process type (material, mental, relational, verbal,
behavioral, existential) and extracts participants and circumstances. This
pass is deterministic, fast (~50ms/clause), and never fails silently.

**Pass 2** (see `lib/sfl/compiler/pass_two/pass_two_engine.rb`) uses DSPy.rb
with an LLM to annotate interpersonal features: mood, modality weight
(0.0–1.0), tenor (0.0–1.0), and speaker attitude. This pass is batched
(~12 clauses per LLM call, 4 concurrent calls) with a retry-and-fallback
degradation ladder — transient chunk failures get one retry, persistent
failures fall back to defaults marked `annotation_source: "fallback"` so
they are never silently presented as measurement.

### The Result: Enriched Storage

After both passes, each clause carries two payloads:

```ruby
# The ideational payload (what is happening)
ideational.process_type    # => "material"
ideational.participants    # => [#<Participant role="Actor", text="server">, ...]
ideational.circumstances   # => ["at peak load"]

# The interpersonal payload (how it was said)
interpersonal.mood             # => "declarative"
interpersonal.modality_weight  # => 0.85
interpersonal.tenor             # => 0.72
interpersonal.speaker_attitude # => "assertive"
interpersonal.annotation_source # => "llm"
```

These payloads live in separate database tables — `ideational_payloads` and
`interpersonal_payloads` — with independent scalar indices on mood,
modality_weight, and tenor. The vector embedding is stored in a separate
`embeddings` table. The payloads are never fused into the vector; they are
queryable metadata that sits alongside it.

```
┌──────────────────────────────────────────────────────┐
│                   Your Vector Store                   │
│  ┌──────────────────────────────────────────────────┐ │
│  │  clause_id  │  text  │  embedding [768-dim]      │ │
│  │             │        │  (your embedding model)   │ │
│  └──────────────────────────────────────────────────┘ │
│                         │                              │
│          ┌──────────────┼──────────────┐              │
│          ▼              ▼              ▼              │
│  ┌──────────────┐ ┌────────────┐ ┌────────────────┐  │
│  │ ideational_  │ │interperso- │ │  embeddings   │  │
│  │ payloads     │ │ nal_payload│ │  (vector)     │  │
│  │              │ │ s          │ │                │  │
│  │ process_type │ │ mood       │ │ cosine index   │  │
│  │ participants │ │ modality   │ │ (ivfflat)      │  │
│  │ circumstances│ │ tenor      │ │                │  │
│  │              │ │ attitude   │ │                │  │
│  │              │ │ annotation │ │                │  │
│  │              │ │ _source    │ │                │  │
│  └──────────────┘ └────────────┘ └────────────────┘  │
└──────────────────────────────────────────────────────┘
```

### Code: Integrating at Ingestion

The `Pipeline` class (see `lib/sfl/compiler/pipeline.rb`) is the ingestion
middleware entry point. It accepts raw text, runs both passes, stores clauses
and payloads, and optionally generates embeddings:

```ruby
require "sfl-compiler"

ctx = SFL::Compiler::Bootstrap.call   # .env → config, DSPy, database
pipeline = SFL::Compiler::Pipeline.new(
  db: ctx.db,
  embedder: SFL::Compiler::Embedder.new(
    model: ctx.config.embedding_model,
    ollama_base_url: ctx.config.ollama_base_url
  )
)

# Your existing chunking strategy produces text chunks.
# Pass each chunk through the SFL pipeline before embedding:
chunks.each do |chunk_text|
  pipeline.compile(chunk_text, document_id: "doc-1")
  # The chunk is now annotated, stored, and embedded.
  # SFL metadata sits in payload tables alongside the vector.
end
```

If you want to use your own embedding model instead of the SFL Compiler's
built-in Ollama `embeddinggemma` embedder, simply omit the `embedder:`
argument and run the embedding step yourself after `pipeline.compile`
returns the `AnnotatedClause` objects:

```ruby
annotated = pipeline.compile(chunk_text, document_id: "doc-1", embed: false)
annotated.each do |ac|
  vector = your_embedding_model.embed(ac.text)
  your_vector_store.upsert(id: ac.id, text: ac.text, vector: vector,
                           metadata: { mood: ac.interpersonal.mood,
                                      tenor: ac.interpersonal.tenor,
                                      modality: ac.interpersonal.modality_weight })
end
```

The SFL payloads are available on every `AnnotatedClause` as `ac.ideational`
and `ac.interpersonal`. Store them wherever your pipeline stores metadata —
in a sidecar database table, in the vector store's metadata field, or in
both.

### What This Costs

- **Pass 1**: ~50ms per clause, no LLM cost, deterministic.
- **Pass 2**: ~2s per clause (amortized across batched LLM calls — ~12
  clauses per call, 4 concurrent calls). This is the primary cost of SFL
  enrichment. For a 100-clause document, expect ~20-30 seconds of LLM time.
- **Storage**: Three payload tables alongside the vector index. The SFL
  metadata is compact (a few scalar columns per clause) and does not
  significantly increase storage requirements.

---

## Part 2: The Retrieval Interceptor (Stance-Filtered Search)

### What You Keep

Your vector database stays. The SFL retrieval interceptor does not replace
your vector index or your semantic search. It wraps the retrieval step with
a filter layer that operates on the SFL metadata stored during ingestion.

Your LLM stays. The interceptor filters what reaches the model's context
window; it does not replace the model. Whatever LLM you use for synthesis
— GPT-4, Claude, Llama, Mistral — receives a filtered, stance-aware
evidence set rather than raw top-K results.

### The Hook: Stance Extraction and RRF + Scalar Filtering

When a user asks a question, the SFL Router intercepts the query and
extracts the desired "Stance" — the SFL filter profile that matches the
query's intent. The router then runs hybrid retrieval (semantic + keyword,
merged with Reciprocal Rank Fusion) and applies scalar stance filters before
the results reach the LLM.

```
User Query
    │
    ▼
┌─────────────────────────┐
│     SFL Router           │
│                          │
│  "Give me only highly    │
│   certain facts"         │
│        │                 │
│        ▼                 │
│  Stance Extraction       │
│  min_modality: 0.8       │
│  min_tenor: 0.6          │
│  mood: "declarative"     │
└──────────┬──────────────┘
           │
           ▼
┌──────────────────────────────────────┐
│    Hybrid Retrieval (RRF)            │
│                                      │
│  Semantic Search ──┐                  │
│                   ├──► RRF Merge     │
│  Keyword Search ──┘    (k=60)        │
│                         │             │
│                         ▼             │
│              Scalar Stance Filters    │
│              (mood, modality,         │
│               tenor, process_type)    │
│                         │             │
│                         ▼             │
│              Filtered Evidence        │
└──────────────────────┬─────────────────┘
                       │
                       ▼
┌──────────────────────────────────────┐
│    LLM Synthesis                     │
│                                      │
│  Context window receives:            │
│  - Numbered evidence clauses         │
│  - SFL annotations per clause        │
│  - Ideational content (facticity)    │
│  - Interpersonal metadata (stance)   │
│  as separate, labeled fields         │
│                                      │
│  Output: grounded answer + citations │
└──────────────────────────────────────┘
```

### Stance Extraction

The SFL Router maps query intent to scalar filter parameters. The mapping is
configurable — you decide which queries trigger which filters. Some examples:

```
Query Intent                          Stance Filter
─────────────────────────────────────────────────────
"Give me only highly certain facts"   min_modality: 0.8
"Find formal documentation"          min_tenor: 0.7
"Show me action items, not history"  mood: "imperative",
                                      process_type: "material"
"Exclude opinions, only facts"       min_modality: 0.7,
                                      min_tenor: 0.6,
                                      mood: "declarative"
"Find instructions, not definitions" mood: "imperative",
                                      process_type: "material"
```

The router can be rule-based (keyword matching on the query), LLM-based
(the LLM extracts the stance from the query before retrieval), or a hybrid.
The SFL Compiler's CLI provides a simple rule-based router via command-line
flags; programmatic users can build a more sophisticated router on top.

### Reciprocal Rank Fusion (RRF)

The `HybridRetriever` (see `lib/sfl/compiler/retrieval/hybrid_retriever.rb`)
combines two search streams:

1. **Semantic search** — pgvector cosine similarity between the query
   embedding and stored clause embeddings. This is your standard vector
   search, unchanged.
2. **Keyword search** — PostgreSQL full-text search
   (`to_tsvector @@ plainto_tsquery`). This is your standard keyword search,
   unchanged.

The two result lists are merged with Reciprocal Rank Fusion:

```
score(d) = Σ 1/(60 + rank_i(d))    for each list i
```

RRF normalizes by rank, not by raw score — so a clause that appears in both
semantic and keyword results ranks higher than one that appears in only
one. This is the standard RRF algorithm; the SFL Compiler does not modify
it.

### Scalar Stance Filters

After RRF merges the result lists, the `apply_filters` method (lines 164–199
of `hybrid_retriever.rb`) evaluates each candidate clause against the
interpersonal payload:

```ruby
next false if filters[:mood] && interpersonal[:mood] != filters[:mood]
next false if filters[:min_modality] && interpersonal[:modality_weight] < filters[:min_modality]
next false if filters[:max_modality] && interpersonal[:modality_weight] > filters[:max_modality]
next false if filters[:min_tenor] && interpersonal[:tenor] < filters[:min_tenor]
next false if filters[:max_tenor] && interpersonal[:tenor] > filters[:max_tenor]
next false if filters[:process_type] && ideational[:process_type] != filters[:process_type]
```

Clauses that fail the filter are excluded from the result set. They never
enter the synthesis prompt. The LLM never sees them. This is the Rhetorical
Firewall — a deterministic gate that operates before the model's input is
assembled, not after.

### Code: Integrating at Retrieval

The `HybridRetriever` and `ContextSynthesizer` are the retrieval interceptor
entry points. For the simplest integration, use them directly:

```ruby
retriever = SFL::Compiler::HybridRetriever.new(db: ctx.db, embedder: embedder)

# Retrieve with stance filters
results = retriever.retrieve(
  "input validation",
  limit: 10,
  filters: {
    min_modality: 0.8,    # only highly certain clauses
    min_tenor: 0.6,      # only formal/objective register
    mood: "declarative"  # only statements, not commands
  }
)
# results contains only clauses that passed both RRF ranking AND stance filters
```

For full synthesis (retrieval + LLM answer generation), use the
`ContextSynthesizer`:

```ruby
synthesizer = SFL::Compiler::ContextSynthesizer.new(
  retriever: retriever,
  clause_repo: SFL::Compiler::ClauseRepository.new(ctx.db)
)

answer = synthesizer.synthesize(
  "what is scalar filtering used for?",
  filters: { min_modality: 0.7 },
  limit: 5
)
# answer.answer          => "Scalar filtering lets you..."
# answer.confidence      => 0.82
# answer.cited_clause_ids => ["uuid-1", "uuid-3", "uuid-7"]
```

The `ContextSynthesizer` formats the retrieved clauses as numbered evidence
with SFL annotations alongside each clause:

```
[1] The system validates each request against the schema.
    (mood=declarative, tenor=0.85, modality=0.9, process=material; source: docs/architecture.md)
[2] Validation failures raise an error immediately.
    (mood=declarative, tenor=0.72, modality=0.8, process=material; source: docs/guides/USAGE.md)
```

The LLM receives this structured evidence — ideational content and
interpersonal metadata as separate, labeled fields — rather than fused prose.
This is the facticity/interpretation separation that de-fangs parahuman
manipulation (see
[docs/use-cases/llm-role-isolation.md — De-fanging the
Prompt](../use-cases/llm-role-isolation.md#de-fanging-the-prompt-ideationalinterpersonal-separation)).

### Using SFL Filters with Your Existing Retriever

If you already have a LangChain, LlamaIndex, or custom retriever, you do not
need to replace it with `HybridRetriever`. You can apply SFL stance filters as
a post-retrieval step:

```ruby
# 1. Your existing retriever produces candidate clauses
candidates = your_existing_retriever.retrieve(query, limit: 30)

# 2. Fetch SFL metadata for each candidate
sfl_metadata = fetch_interpersonal_payloads(candidates.map(&:id))

# 3. Apply scalar stance filters
filtered = candidates.select do |clause|
  meta = sfl_metadata[clause.id]
  meta &&                            # clause has SFL annotation
    meta[:modality_weight] >= 0.7 && # only high-certainty
    meta[:tenor] >= 0.6 &&           # only formal register
    meta[:mood] == "declarative"     # only statements
end

# 4. Pass filtered evidence to your LLM
answer = your_llm.synthesize(query, filtered)
```

The SFL metadata is stored in standard SQL tables. Any retriever that can
join on clause IDs can access it. The filter logic is a handful of
comparisons — it does not require the SFL Compiler's retriever at all.

---

## Integration Checklist

```
INGESTION
─────────────────────────────────────────────────────────
[ ] Install SFL Compiler gem: gem "sfl-compiler"
[ ] Install Python spaCy + en_core_web_sm model
[ ] Configure .env: DATABASE_URL, DSPY_PROVIDER, API key
[ ] Configure Ollama for embeddings (or use your own embedder)
[ ] Run migrations: bundle exec rake db:refresh
[ ] Insert Pipeline.compile(chunk_text) before your embedding step
[ ] Verify SFL payloads are stored alongside vectors

RETRIEVAL
─────────────────────────────────────────────────────────
[ ] Choose integration mode:
    [ ] Full: use HybridRetriever + ContextSynthesizer
    [ ] Partial: use your own retriever, apply SRL filters post-retrieval
[ ] Define stance profiles for your query types
[ ] Test: run the same query with and without stance filters
[ ] Verify filtered results exclude low-modality / low-tenor clauses
[ ] Verify LLM answers change when stance filters are applied

VALIDATION
─────────────────────────────────────────────────────────
[ ] Ingest a known document with manipulative text
[ ] Query with min_modality: 0.7, min_tenor: 0.7
[ ] Confirm manipulative clauses are excluded from results
[ ] Compare LLM answers with and without SFL filtering
[ ] Check annotation_source: fallback/stub clauses are excluded
    from synthesis by default (ContextSynthesizer does this)
```

---

## Related

- [README — The Core Hypothesis: Stance-Filtered RAG (Safe RAG)](../../README.md#the-core-hypothesis-stance-filtered-rag-safe-rag)
- [README — Scalar Filtering](../../README.md#scalar-filtering)
- [README — Payload Separation](../../README.md#payload-separation)
- [README — Library Usage](../../README.md#library-usage)
- [docs/use-cases/llm-role-isolation.md](../use-cases/llm-role-isolation.md) — the Rhetorical Firewall
- [docs/architectural-lineage.md](../architectural-lineage.md) — interdisciplinary design synthesis
- [lib/sfl/compiler/pipeline.rb](../../lib/sfl/compiler/pipeline.rb) — ingestion entry point
- [lib/sfl/compiler/retrieval/hybrid_retriever.rb](../../lib/sfl/compiler/retrieval/hybrid_retriever.rb) — RRF + scalar filters
- [lib/sfl/compiler/retrieval/context_synthesizer.rb](../../lib/sfl/compiler/retrieval/context_synthesizer.rb) — stance-aware LLM synthesis
- [lib/sfl/compiler/retrieval/embedder.rb](../../lib/sfl/compiler/retrieval/embedder.rb) — embedding interface