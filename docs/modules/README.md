# Modules Documentation

This directory contains detailed documentation for each major module in the sfl-compiler codebase. Each module document follows the SFL writing guide conventions with transformation contracts, dependency mapping, and Ruby Pragmatist insights.

---

## Module Index

| Module | Location | Description |
|--------|----------|-------------|
| **PassOneEngine** | `lib/sfl/compiler/pass_one/pass_one_engine.rb` | spaCy-based syntactic extraction engine |
| **PassTwoEngine** | `lib/sfl/compiler/pass_two/pass_two_engine.rb` | Core LLM annotation engine for interpersonal and textual metafunctions |
| **Pipeline** | `lib/sfl/compiler/pipeline.rb` | Two-pass compilation orchestrator with caching and storage |
| **PipelineCache** | `lib/sfl/compiler/storage/pipeline_cache.rb` | Disk-based cache enabling resume after partial failures |
| **ConversationAnalyzer** | `lib/sfl/compiler/analysis/conversation_analyzer.rb` | Aggregates annotations into turn-level metrics and insights |
| **KnowledgeBaseAnalyzer** | `lib/sfl/compiler/analysis/knowledge_base_analyzer.rb` | Analyzes document collections for content type, quality, and migration readiness |
| **CompileTurnJob** | `lib/sfl/compiler/jobs/compile_turn_job.rb` | Sidekiq/Gush job that compiles one conversation turn in isolation |
| **LangfuseReachability** | `lib/sfl/compiler/langfuse_reachability.rb` | Pre-flight check that verifies Langfuse is reachable before enabling tracing |
| **CrossDocumentGraph** | `lib/sfl/compiler/cross_document_graph.rb` | Query-time graph across stored documents for multi-source synthesis |
| **SprintWorkflow** | `lib/sfl/compiler/workflows/sprint_workflow.rb` | Batch workflow that runs analyses and collects per-item failures |
| **HybridRetriever** | `lib/sfl/compiler/retrieval/hybrid_retriever.rb` | RRF fusion of semantic + keyword search with scalar filters |
| **ContextSynthesizer** | `lib/sfl/compiler/retrieval/context_synthesizer.rb` | Retrieval → cited, stance-annotated LLM answer synthesis |
| **Embedder** | `lib/sfl/compiler/retrieval/embedder.rb` | Text → 768-dim vector embedding via Ollama |
| **Database** | `lib/sfl/compiler/storage/database.rb` | Sequel connection, fiber-safe pool config, extension setup, migrations |
| **TenorTracker** | `lib/sfl/compiler/analysis/tenor_tracker.rb` | Formality shift detection across conversation turns |
| **CohesionAnalyzer** | `lib/sfl/compiler/analysis/cohesion_analyzer.rb` | Lexical repetition, conjunction, and pronoun density metrics |
| **SpeakerProfiler** | `lib/sfl/compiler/analysis/speaker_profiler.rb` | Per-speaker linguistic pattern aggregation |
| **CorrelationAnalyzer** | `lib/sfl/compiler/analysis/correlation_analyzer.rb` | Process type × tenor/modality correlation analysis |
| **TopicModeler** | `lib/sfl/compiler/analysis/topic_modeler.rb` | LDA/HDP topic clustering for conversation turns |

---

## Community Map

The modules are organized by their functional communities:

### Core Pipeline
- PassOneEngine
- PassTwoEngine
- Pipeline
- IdeationalExtractor

### Parallel Processing
- CompileTurnJob
- CompileSectionJob
- SprintWorkflow

### Storage & Caching
- PipelineCache
- ClauseRepository
- EmbeddingRepository
- Database

### Analysis & Aggregation
- ConversationAnalyzer
- KnowledgeBaseAnalyzer
- TenorTracker
- CohesionAnalyzer
- SpeakerProfiler
- CorrelationAnalyzer
- TopicModeler

### Retrieval
- Embedder
- HybridRetriever
- ContextSynthesizer
- CrossDocumentGraph

### Formatting & Output
- CSVFormatter
- JSONFormatter
- MarkdownFormatter
- NarrativeFormatter
- NarrativeGenerator
- KBReportWriter

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
