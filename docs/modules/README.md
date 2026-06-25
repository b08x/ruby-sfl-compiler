# Modules Documentation

This directory contains detailed documentation for each major module in the sfl-compiler codebase. Each module document follows the SFL writing guide conventions with transformation contracts, dependency mapping, and Ruby Pragmatist insights.

---

## Module Index

| Module | Location | Description |
|--------|----------|-------------|
| **PassTwoEngine** | `lib/sfl/compiler/pass_two/pass_two_engine.rb` | Core LLM annotation engine for interpersonal and textual metafunctions |
| **PipelineCache** | `lib/sfl/compiler/storage/pipeline_cache.rb` | Disk-based cache enabling resume after partial failures |
| **ConversationAnalyzer** | `lib/sfl/compiler/analysis/conversation_analyzer.rb` | Aggregates annotations into turn-level metrics and insights |
| **CompileTurnJob** | `lib/sfl/compiler/jobs/compile_turn_job.rb` | Sidekiq/Gush job that compiles one conversation turn in isolation |
| **LangfuseReachability** | `lib/sfl/compiler/langfuse_reachability.rb` | Pre-flight check that verifies Langfuse is reachable before enabling tracing |
| **CrossDocumentGraph** | `lib/sfl/compiler/cross_document_graph.rb` | Query-time graph across stored documents for multi-source synthesis |
| **SprintWorkflow** | `lib/sfl/compiler/workflows/sprint_workflow.rb` | Batch workflow that runs analyses and collects per-item failures |

---

## Community Map

The modules are organized by their functional communities:

### Core Pipeline
- PassTwoEngine
- PassOneEngine
- SFLAnnotator / SFLBatchAnnotator
- Pipeline

### Parallel Processing
- CompileTurnJob
- SprintWorkflow

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
- CrossDocumentGraph

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
