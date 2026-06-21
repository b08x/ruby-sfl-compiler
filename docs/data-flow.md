# Data Flow

The sfl-compiler data flow **prioritizes** deterministic transformation of text through well-defined stages **while** accommodating the non-deterministic nature of LLM annotations through caching and validation.

---

## Primary Operation: Conversation Analysis Pipeline

```mermaid
sequenceDiagram
    participant User
    participant CLI as CLI
    participant Config as Bootstrap
    participant Loader as MarkdownLoader
    participant P1 as PassOneEngine
    participant CR as ClauseRepository
    participant P2 as PassTwoEngine
    participant PC as PipelineCache
    participant ER as EmbeddingRepository
    participant CA as ConversationAnalyzer
    participant CO as CohesionAnalyzer
    participant SP as SpeakerProfiler
    participant TT as TenorTracker
    participant TM as TopicModeler
    participant FM as Formatters
    
    User->>CLI: sfl-analyze conversation input.md --output-dir ./output
    CLI->>Config: load_configuration()
    Config-->>CLI: Configuration (LLM, DB, timeouts)
    CLI->>Loader: load_file(input.md)
    Loader-->>CLI: Document text
    CLI->>P1: process_document()
    
    %% Pass 1: Syntactic Parsing
    P1->>P1: Tokenize with spaCy
    P1->>P1: Parse dependency tree
    P1->>P1: Extract clauses
    P1->>P1: Ideational extraction
    P1->>CR: store_clauses()
    CR-->>P1: Clause IDs
    P1->>P1: Build SyntacticClause objects
    P1-->>CLI: Pass 1 complete: N clauses
    
    %% Pass 2: Semantic Annotation
    CLI->>P2: annotate_document()
    P2->>PC: check_cache(clause)
    
    alt Cache hit
        PC-->>P2: Cached AnnotatedClause
    else Cache miss
        P2->>P2: Build LLM prompt
        P2->>P2: Call LLM (mood, modality, tenor, attitude)
        P2->>P2: Textual extraction (theme, rheme, type)
        P2->>P2: Normalize theme_type
        P2->>P2: Validate annotations
        P2->>ER: store_embedding() (optional)
        P2->>PC: store_cache()
    end
    P2-->>CA: Fully annotated clauses
    
    %% Aggregation
    CA->>CO: calculate_cohesion()
    CO-->>CA: CohesionMetrics
    CA->>SP: profile_speakers()
    SP-->>CA: SpeakerProfile[]
    CA->>TT: track_tenor()
    TT-->>CA: Tenor shifts, key moments
    CA->>TM: model_topics()
    TM-->>CA: TopicModel
    CA->>CA: Correlate process types
    CA->>CA: Detect example passages
    CA->>CA: Build AnalysisResult
    
    %% Output
    CA->>FM: format_results()
    FM->>FM: Generate CSV
    FM->>FM: Generate JSON
    FM->>FM: Generate Markdown
    FM-->>User: Write output files
```

**Transformation Pipeline**:
1. **[Input Stage]**: MarkdownLoader **provides** document text **at** CLI invocation **through** file loading **for** downstream parsing
2. **[Validation Stage]**: Bootstrap **verifies** LLM and database configuration **producing** validated Configuration **or** clear error messages
3. **[Pass 1 Processing]**: PassOneEngine **transforms** raw text **into** syntactic clauses with IdeationalPayload **using** spaCy dependency parsing **generating** 1-N clauses per sentence
4. **[Pass 1 Storage]**: ClauseRepository **persists** syntactic clauses **as** PostgreSQL records **with** document_id, sentence_index, tokens, dependencies **enabling** resume and retrieval
5. **[Pass 2 Cache Check]**: PipelineCache **checks** for existing annotations **using** deterministic cache key (document_id + sentence_index + clause_text) **returning** cached results **if** available
6. **[Pass 2 Annotation]**: PassTwoEngine **transforms** syntactic clauses **into** AnnotatedClause **using** LLM prompts **producing** InterpersonalPayload + TextualPayload **with** circuit breaker protection
7. **[Pass 2 Storage]**: EmbeddingRepository **stores** vector embeddings **as** pgvector-encoded arrays **with** model identifier **enabling** semantic retrieval
8. **[Aggregation Stage]**: ConversationAnalyzer **aggregates** annotated clauses **into** turn-level metrics **including** CohesionMetrics (repetition_score, conjunction_density, pronoun_density), SpeakerProfile, KeyMoment[], ExamplePassage[]
9. **[Output Stage]**: Formatters **serialize** AnalysisResult **as** CSV (for spreadsheet analysis), JSON (for programmatic access), Markdown (for human reading) **with** data quality sections

---

## Secondary Flows

### Documentation Analysis Flow

```mermaid
sequenceDiagram
    participant User
    participant CLI as CLI
    participant DA as DocumentationAnalyzer
    participant P1 as PassOneEngine
    participant P2 as PassTwoEngine
    participant CA as ConversationAnalyzer
    
    User->>CLI: sfl-analyze documentation ./docs --output-dir ./output
    CLI->>DA: analyze_documentation()
    DA->>P1: Extract clauses from all markdown files
    P1-->>DA: Syntactic clauses
    DA->>P2: Annotate interpersonal + textual
    P2-->>DA: Annotated clauses
    DA->>CA: Aggregate with documentation focus
    CA->>DA: AnalysisResult with tenor tracking
    DA->>DA: Generate documentation-specific insights
    DA-->>User: Documentation analysis report
```

**Critical Path**: DocumentationAnalyzer **coordinates** multi-file processing **enabling** corpus-wide linguistic analysis.

---

### Context Synthesis Flow

```mermaid
sequenceDiagram
    participant User
    participant CLI as CLI
    participant CS as ContextSynthesizer
    participant HR as HybridRetriever
    participant EM as Embedder
    
    User->>CLI: sfl-analyze context QUERY --collection codebase
    CLI->>CS: run_context()
    CS->>HR: search(hybrid: true, query: QUERY)
    HR->>EM: embed(QUERY)
    EM-->>HR: Query vector
    HR->>HR: Keyword search (parallel)
    HR->>HR: Semantic search (parallel)
    HR->>HR: RRF fusion of results
    HR-->>CS: Retrieved clauses with similarity scores
    CS->>CS: Synthesize context from results
    CS->>CS: Generate answer with citations
    CS-->>User: Context synthesis with evidence
```

**Critical Path**: HybridRetriever **combines** keyword and semantic search **using** Reciprocal Rank Fusion **to produce** comprehensive retrieval results.

---

### Resume Flow (After Failure)

```mermaid
sequenceDiagram
    participant User
    participant CLI as CLI
    participant Config as Bootstrap
    participant PC as PipelineCache
    participant P1 as PassOneEngine
    participant P2 as PassTwoEngine
    
    User->>CLI: sfl-analyze conversation input.md --resume
    CLI->>Config: load_configuration()
    CLI->>PC: check_resume_state()
    PC-->>CLI: Last completed stage
    
    alt Resume from Pass 2
        CLI->>P2: resume_from_cache()
        P2->>PC: load_cached_pass1()
        PC-->>P2: Cached syntactic clauses
        P2->>P2: Continue with Pass 2
        P2-->>User: Resume complete
    else Resume from Pass 1
        CLI->>P1: resume_from_cache()
        P1->>PC: load_cached_tokens()
        PC-->>P1: Cached spaCy results
        P1->>P1: Continue with ideational extraction
        P1-->>User: Pass 1 complete, starting Pass 2
    end
```

**Critical Path**: PipelineCache **enables** resume from exact failure point **by** storing intermediate results **with** deterministic cache keys.

---

## Data Model Flow

```mermaid
flowchart TD
    subgraph Input["Input Data"]
        MD[Markdown\nText] --> ML[MarkdownLoader]
    end
    
    subgraph Parsing["Parsing"]
        ML --> PE[PassOneEngine]
        PE --> SC[SyntacticClause]
        SC --> CR[ClauseRepository]
    end
    
    subgraph Annotating["Annotation"]
        SC --> P2E[PassTwoEngine]
        P2E --> IP[InterpersonalPayload]
        P2E --> TP[TextualPayload]
        P2E --> AC[AnnotatedClause]
    end
    
    subgraph Aggregating["Aggregation"]
        AC --> CA[ConversationAnalyzer]
        CA --> CM[CohesionMetrics]
        CA --> SP[SpeakerProfile]
        CA --> TT[TenorTracker]
        CA --> TM[TopicModeler]
        CA --> AR[AnalysisResult]
    end
    
    subgraph Storing["Storage"]
        AC --> ER[EmbeddingRepository]
        SC --> CR2[ClauseRepository]
        AC --> PC[PipelineCache]
    end
    
    subgraph Output["Output"]
        AR --> CF[CSVFormatter]
        AR --> JF[JSONFormatter]
        AR --> MF[MarkdownFormatter]
        AR --> NF[NarrativeFormatter]
    end
    
    MD -.->|resume| PC
    PC -.->|cache hit| AC
    
    classDef input fill:#1e293b,stroke:#64748b,color:#fff
    classDef parsing fill:#064e3b,stroke:#10b981,color:#fff
    classDef annotating fill:#7c2d12,stroke:#f59e0b,color:#fff
    classDef aggregating fill:#7c2d12,stroke:#f59e0b,color:#fff
    classDef storing fill:#334155,stroke:#475569,color:#fff
    classDef output fill:#1e293b,stroke:#64748b,color:#fff
    
    class MD,ML input
    class PE,SC,CR parsing
    class P2E,IP,TP,AC annotating
    class CA,CM,SP,TT,TM,AR aggregating
    class ER,CR2,PC storing
    class CF,JF,MF,NF output
```

---

## Critical Paths

| Path | Data Journey | Enables | Confidence |
|------|--------------|---------|------------|
| **Business Critical** | Markdown → Pass1 → Pass2 → Analysis → Markdown report | Core linguistic analysis for users | EXTRACTED |
| **Performance Critical** | Clause → Embedding → Vector Storage → Semantic Retrieval | Efficient similar-clause finding | EXTRACTED |
| **Resilience Critical** | Pass2 partial failure → Cache → Resume | Recovery from LLM timeouts | EXTRACTED |
| **Quality Critical** | AnnotatedClause → Validation → Normalization | Consistent theme_type values | EXTRACTED |
| **Fallback Critical** | pgvector unavailable → Keyword-only retrieval | Graceful degradation | INFERRED |

---

## Embedding Data Flow

```mermaid
sequenceDiagram
    participant Text as Input Text
    participant EM as Embedder
    participant ER as EmbeddingRepository
    participant DB as PostgreSQL
    participant HR as HybridRetriever
    
    Text->>EM: embed(text)
    EM->>EM: Validate text (nil/empty check)
    EM->>EM: Configure RubyLLM (Ollama)
    EM->>EM: Call RubyLLM.embed()
    EM->>EM: Extract vectors from response
    EM-->>Text: vector[Float] or nil
    Text->>ER: store(clause_id, vector)
    ER->>ER: Encode with Pgvector.encode()
    ER->>DB: INSERT into embeddings table
    DB-->>ER: Success
    ER-->>Text: Stored
    
    HR->>EM: embed(query)
    EM-->>HR: query_vector
    HR->>ER: search(query_vector, limit: 10)
    ER->>ER: Encode query_vector with Pgvector.encode()
    ER->>DB: SELECT ... ORDER BY embedding <=> vector
    DB-->>ER: Results with similarity scores
    ER-->>HR: Clause matches
```

**Transformation Contract**:
Embedder **transforms** text strings **into** 768-dimensional float vectors **through** Ollama's embeddinggemma model **when** text is non-empty and Ollama is accessible.

---

## Pipeline Cache Data Flow

```mermaid
flowchart TD
    subgraph "Cache Key Generation"
        DI[document_id] --> CONCAT(( ))
        SI[sentence_index] --> CONCAT
        CT[clause_text] --> CONCAT
        CONCAT --> SHA256[SHA256 hash]
    end
    
    subgraph "Cache Operations"
        SHA256 --> PATH[cache_path]
        PATH --> EXISTS{exists?}
        EXISTS -->|yes| LOAD[Load JSON]
        EXISTS -->|no| SAVE[Save JSON]
        LOAD --> RECONSTRUCT[Reconstruct objects]
        RECONSTRUCT --> RETURN[Return cached]
        SAVE --> STORE[Store to disk]
    end
    
    classDef process fill:#0f172a,stroke:#38bdf8,color:#e0f2fe
    classDef decision fill:#7c2d12,stroke:#f59e0b,color:#fef3c7
    classDef action fill:#064e3b,stroke:#10b981,color:#d1fae5
    
    class DI,SI,CT CONCAT process
    class EXISTS decision
    class LOAD,SAVE,RECONSTRUCT,RETURN,STORE action
```

**Transformation Contract**:
PipelineCache **transforms** in-memory AnnotatedClause objects **into** JSON files on disk **keyed by** SHA256(document_id + sentence_index + clause_text) **enabling** deterministic cache lookups and resume capability.

---

## Ruby Pragmatist Data Flow Insight

The sfl-compiler data flow works like a **conveyor belt with quality checkpoints** — it **moves text through precisely calibrated stations (syntax parsing, semantic annotation, aggregation) where each stage adds value and stamps its quality mark**, much like a modern manufacturing line, **while the LLM stations occasionally need recalibration and the belt can remember where it left off thanks to the caching notebook**, ensuring that even if the line stops, production can resume without losing work.
