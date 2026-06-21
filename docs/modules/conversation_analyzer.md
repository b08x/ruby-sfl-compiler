# ConversationAnalyzer

**Location**: `lib/sfl/compiler/analysis/conversation_analyzer.rb`
**Confidence**: EXTRACTED
**Community**: Conversation Analysis
**God Node Rank**: #3 (15 edges)

---

## Transformation Contract *(Material Processes — lead with this)*

ConversationAnalyzer **transforms** arrays of AnnotatedClause objects **into** AnalysisResult objects **through** aggregation across multiple analysis dimensions **when** all clauses belong to the same conversation/document.

> AnalysisResult **contains** turn-level metrics, speaker profiles, cohesion metrics, key moments, example passages, and data quality information.

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

---

## Key Components

| Component | Type | Transformation / Role | Confidence |
|-----------|------|-----------------------|------------|
| `CohesionAnalyzer` | Dependency | **Calculates** CohesionMetrics per turn/section | EXTRACTED |
| `SpeakerProfiler` | Dependency | **Builds** SpeakerProfile from per-speaker clauses | EXTRACTED |
| `TenorTracker` | Dependency | **Tracks** tenor shifts and detects key moments | EXTRACTED |
| `TopicModeler` | Dependency | **Models** topics across conversation | EXTRACTED |
| `CorrelationAnalyzer` | Dependency | **Correlates** process types with interpersonal features | EXTRACTED |

---

## Dependencies *(Relational Processes)*

**Requires**:
- **[PassTwoEngine]**: **provides** AnnotatedClause[] **for** analysis input
  - Failure: No clauses to analyze | Mitigation: Early return with empty result
- **[CohesionAnalyzer]**: **provides** lexical repetition, conjunction density, pronoun density metrics
  - Failure: Returns zero metrics | Mitigation: Graceful degradation with zero values
- **[SpeakerProfiler]**: **provides** per-speaker modality and process type patterns
  - Failure: Returns empty profiles | Mitigation: Continues with available data
- **[TenorTracker]**: **provides** formality tracking and shift detection
  - Failure: Returns empty tracking | Mitigation: Key moments list may be incomplete
- **[TopicModeler]**: **provides** topic assignments and clustering
  - Failure: Returns empty model | Mitigation: Topic information omitted from output

**Enables**:
- **[Formatters]**: **uses** AnalysisResult **for** CSV/JSON/Markdown output
- **[NarrativeGenerator]**: **uses** AnalysisResult **for** human-readable narrative generation
- **[ContextSynthesizer]**: **uses** aggregated insights **for** semantic search enrichment

---

## Interactions

```mermaid
flowchart TD
    subgraph Input["Input"]
        AC[AnnotatedClause[]]
    end
    
    subgraph Processing["ConversationAnalyzer"]
        CA[ConversationAnalyzer]
        G[Group by Turn]
        CO[CohesionAnalyzer]
        SP[SpeakerProfiler]
        TT[TenorTracker]
        TM[TopicModeler]
        CR[CorrelationAnalyzer]
        DQ[Data Quality]
        AG[Aggregate Results]
    end
    
    subgraph Output["Output"]
        AR[AnalysisResult]
    end
    
    AC --> CA
    CA --> G
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
    
    AG --> AR
    
    classDef input fill:#064e3b,stroke:#10b981,color:#fff
    classDef processing fill:#7c2d12,stroke:#f59e0b,color:#fff
    classDef output fill:#064e3b,stroke:#10b981,color:#fff
```

---

## What Users / Developers Experience *(Mental Processes)*

- **First encounter**: Users **typically** see turn-level metrics first **and** then drill into speaker profiles or key moments.
- **After regular use**: Cohesion patterns **often reveal** conversation structure **while** tenor shifts **highlight** important transitions.
- **Debugging focus**: Data quality warnings **frequently point to** clauses with fallback interpersonal values **or** parsing errors.

---

## Known Limitations

**Works well when**:
- Conversation has clear turn/speaker boundaries
- Clauses are properly annotated with interpersonal and textual features
- Multiple turns provide statistical significance for metrics
- Speaker identification is consistent

**May struggle with**:
- Single-turn conversations (limited aggregation value)
- Missing speaker information (affects SpeakerProfiler)
- Clauses with stub/fallback interpersonal values (affects data quality)
- Very short conversations (<10 clauses)

**Requires workarounds for**:
- Single speaker → SpeakerProfiler returns single profile
- No tenor variation → TenorTracker returns flat line
- All clauses in one turn → Cohesion metrics calculated at document level

---

## Analysis Dimensions

### Cohesion Metrics

CohesionAnalyzer **calculates** three dimensions of textual cohesion:

| Metric | Calculation | Purpose |
|--------|-------------|---------|
| `repetition_score` | Lexical repetition rate | Measures thematic consistency |
| `conjunction_density` | Conjunctions per clause | Measures logical flow |
| `pronoun_density` | Pronouns per clause | Measures referential cohesion |

**Confidence**: EXTRACTED from CohesionMetrics struct definition.

---

### Speaker Profiling

SpeakerProfiler **aggregates** per-speaker statistics:

| Metric | Calculation | Purpose |
|--------|-------------|---------|
| `tenor` | Average formality | Characterizes speaker style |
| `modality_weight` | Average certainty | Measures confidence level |
| `process_types` | Process type distribution | Identifies action patterns |
| `mood_distribution` | Mood frequency | Reveals declarative/interrogative patterns |

**Confidence**: EXTRACTED from SpeakerProfile struct definition.

---

### Tenor Tracking

TenorTracker **identifies** formality patterns and shifts:

| Feature | Calculation | Purpose |
|---------|-------------|---------|
| Tenor shifts | Change in formality score between turns | Detects tone changes |
| Key moments | Turns with tenor shift > threshold | Highlights significant transitions |
| Formality score | Aggregated from clause-level tenor | Measures overall formality |

**Confidence**: EXTRACTED from TenorTracker and KeyMoment struct definitions.

---

### Topic Modeling

TopicModeler **clusters** clauses by semantic similarity:

| Feature | Calculation | Purpose |
|---------|-------------|---------|
| Topic assignment | Cosine distance clustering | Groups similar clauses |
| Topic names | LLM-generated labels | Provides semantic interpretation |
| Tokenization | Text preprocessing | Normalizes for comparison |

**Confidence**: INFERRED from TopicModeler implementation.

---

## Design Rationale

### Multi-Dimensional Analysis

**Context**: Single metric **cannot capture** conversation complexity.

**Decision**: Aggregate across cohesion, speaker, tenor, topic, and correlation dimensions.

**Rationale**: **Provides** comprehensive view **while** each dimension **reveals** different aspects of linguistic patterns.

**Trade-offs**: More complex output structure; some metrics **may** be redundant for certain use cases.

**Confidence**: EXTRACTED from ConversationAnalyzer implementation.

---

### Data Quality Tracking

**Context**: LLM annotations **may** produce fallback or stub values.

**Decision**: Track data quality and flag affected clauses in output.

**Rationale**: **Enables** users to assess result reliability **and** identify problematic input.

**Trade-offs**: Additional processing overhead; quality metrics **add** complexity to output.

**Confidence**: EXTRACTED from data quality section generation.

---

## Ruby Pragmatist Insight

ConversationAnalyzer works like a **conversation orchestra conductor** — it **takes the individual notes (clauses) and weaves them into a symphony of insights (turns, speakers, topics, cohesion)**, much like a skilled conductor bringing together disparate musicians, **while each section (cohension, speaker, tenor) plays its own instrument and the conductor must ensure they all harmonize into a coherent whole**.
