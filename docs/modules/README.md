# Modules Documentation

This directory contains detailed documentation for each major module in the sfl-compiler codebase. Each module document follows the SFL writing guide conventions with transformation contracts, dependency mapping, and Ruby Pragmatist insights.

---

## Module Index

| Module | Location | God Node Rank | Description |
|--------|----------|---------------|-------------|
| **PassTwoEngine** | `lib/sfl/compiler/pass_two/pass_two_engine.rb` | #1 (21 edges) | Core LLM annotation engine for interpersonal and textual metafunctions |
| **PipelineCache** | `lib/sfl/compiler/storage/pipeline_cache.rb` | #2 (19 edges) | Disk-based cache enabling resume after partial failures |
| **ConversationAnalyzer** | `lib/sfl/compiler/analysis/conversation_analyzer.rb` | #3 (15 edges) | Aggregates annotations into turn-level metrics and insights |

---

## Community Map

The modules are organized by their functional communities as identified by graphify:

### Core Pipeline
- PassTwoEngine
- PassOneEngine
- SFLAnnotator / SFLBatchAnnotator

### Storage & Caching
- PipelineCache
- ClauseRepository
- EmbeddingRepository
- Database

### Analysis & Aggregation
- ConversationAnalyzer
- CohesionAnalyzer
- SpeakerProfiler
- TenorTracker
- TopicModeler
- CorrelationAnalyzer

### Retrieval
- Embedder
- HybridRetriever

### Formatting & Output
- CSVFormatter
- JSONFormatter
- MarkdownFormatter
- NarrativeFormatter
- NarrativeGenerator

---

## Documentation Structure

Each module document includes:

1. **Transformation Contract** - What the module transforms, how, and under what conditions
2. **Responsibilities** - Bullet list of key functions
3. **Key Components** - Table of internal components with their roles
4. **Dependencies** - What the module requires and what it enables
5. **Interactions** - Mermaid diagram of internal data flow
6. **User/Developer Experience** - What users typically encounter
7. **Known Limitations** - Edge cases and constraints
8. **Design Rationale** - Why key decisions were made
9. **Ruby Pragmatist Insight** - Analogy revealing capability and limitation

---

## Confidence Tags

All module documentation uses graphify confidence tags:
- **EXTRACTED** - Directly observed from source code
- **INFERRED** - Deduced from code structure and patterns
- **AMBIGUOUS** - Uncertain or requiring verification

---

## See Also

- [Main Documentation](../README.md) - Project overview and getting started
- [Architecture](../architecture.md) - System component relationships
- [Data Flow](../data-flow.md) - Sequence diagrams and pipelines
- [Design Decisions](../decisions.md) - Rationale behind key choices
