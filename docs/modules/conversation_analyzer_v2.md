# ConversationAnalyzer (Enhanced)

**Location**: `lib/sfl/compiler/analysis/conversation_analyzer.rb`
**Confidence**: PROPOSED
**Community**: Conversation Analysis
**God Node Rank**: #3 (15 edges)

---

## Transformation Contract *(Material Processes — lead with this)*

ConversationAnalyzer **transforms** arrays of AnnotatedClause objects **into** AnalysisResult objects **through** aggregation across multiple analysis dimensions **when** all clauses belong to the same conversation/document.

> **NEW**: ConversationAnalyzer **integrates** with **[PipelineCache]** **to** cache and retrieve AnalysisResult objects **keyed by** a deterministic hash of the input AnnotatedClause array, **enabling** rapid retrieval of previously computed analysis results without re-aggregation.

---

## Responsibilities

- Group clauses by turn/speaker
- Calculate cohesion metrics (repetition_score, conjunction_density, pronoun_density)
- Profile speakers by linguistic patterns
- Track tenor and modality shifts across conversation
- Model topics using cosine distance and clustering
- Correlate process types with interpersonal features
- Detect key moments (tenor/modality shifts beyond threshold)
- Identify example passages (most formal/casual/certain/hedged)
- Generate data quality reports for fallback/stub values
- **NEW**: Cache AnalysisResult to **[PipelineCache]**
- **NEW**: Retrieve AnalysisResult from **[PipelineCache]** if available

---

## Key Components

| Component | Type | Transformation / Role | Confidence |
|-----------|------|-----------------------|------------|
| `CohesionAnalyzer` | Dependency | **Calculates** CohesionMetrics per turn/section | EXTRACTED |
| `SpeakerProfiler` | Dependency | **Builds** SpeakerProfile from per-speaker clauses | EXTRACTED |
| `TenorTracker` | Dependency | **Tracks** tenor shifts and detects key moments | EXTRACTED |
| `TopicModeler` | Dependency | **Models** topics across conversation | EXTRACTED |
| `CorrelationAnalyzer` | Dependency | **Correlates** process types with interpersonal features | EXTRACTED |
| `PipelineCache` | **Dependency** | **Provides** caching/retrieval of AnalysisResult | **PROPOSED** |

---

## Dependencies *(Relational Processes)*

**Requires**:
- **[PassTwoEngine]**: **provides** AnnotatedClause[] **for** analysis input
- **[PipelineCache]**: **provides** persistence for AnalysisResult
- **[CohesionAnalyzer]**, **[SpeakerProfiler]**, **[TenorTracker]**, **[TopicModeler]**, **[CorrelationAnalyzer]**: **provide** analytical metrics

**Enables**:
- **[Formatters]**: **uses** AnalysisResult **for** CSV/JSON/Markdown output
- **[NarrativeGenerator]**: **uses** AnalysisResult **for** human-readable narrative generation

---

## Caching Strategy (New)

The enhanced ConversationAnalyzer will implement the following caching strategy:

1. **Cache Key Generation**: Generate a deterministic SHA256 hash of the input `AnnotatedClause[]` array (including all annotations).
2. **Cache Check**: Before aggregation, check **[PipelineCache]** for the generated key.
3. **Cache Hit**: If found, deserialize and return the cached `AnalysisResult`.
4. **Cache Miss**: If not found, perform aggregation, store the resulting `AnalysisResult` in **[PipelineCache]**, and return the result.

---

## Interactions

```mermaid
flowchart TD
    subgraph Input["Input"]
        AC[AnnotatedClause[]]
    end
    
    subgraph Processing["ConversationAnalyzer"]
        CA[ConversationAnalyzer]
        CACHE{Cache Check}
        G[Group by Turn]
        CO[CohesionAnalyzer]
        SP[SpeakerProfiler]
        TT[TenorTracker]
        TM[TopicModeler]
        CR[CorrelationAnalyzer]
        DQ[Data Quality]
        AG[Aggregate Results]
        STORE[Store in Cache]
    end
    
    subgraph Output["Output"]
        AR[AnalysisResult]
    end
    
    AC --> CA
    CA --> CACHE
    
    CACHE -->|Hit| AR
    CACHE -->|Miss| G
    
    G --> CO
    G --> SP
    G --> TT
    G --> TM
    CA --> CR
    CA --> DQ
    
    CO --> AG
    SP --> AG
    TT --> AG
    TM --> AG
    CR --> AG
    DQ --> AG
    
    AG --> STORE
    STORE --> AR
    
    classDef input fill:#064e3b,stroke:#10b981,color:#fff
    classDef processing fill:#7c2d12,stroke:#f59e0b,color:#fff
    classDef output fill:#064e3b,stroke:#10b981,color:#fff
    classDef cache fill:#1e40af,stroke:#3b82f6,color:#fff
    
    class CACHE,STORE cache
```

---

## Ruby Pragmatist Insight

The enhanced ConversationAnalyzer acts as a **memoized conductor** — it **remembers the final symphony (AnalysisResult) it produced for a specific set of musicians (AnnotatedClause[])**, so if the same orchestra performs again, it **simply retrieves the recorded performance instead of conducting the entire piece from scratch**, saving significant time and computational resources **while** ensuring consistency in the analysis results.
