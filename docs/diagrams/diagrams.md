# Codebase Diagrams

_Mermaid diagrams for architecture visualization and code navigation._

---

## Architecture

High-level module relationships extracted from the codebase graph.

```mermaid
%%{init: {"theme": "dark", "themeVariables": {"fontSize": "15.0px", "fontFamily": "Segoe UI, system-ui, sans-serif", "primaryColor": "#1e293b", "primaryTextColor": "#e2e8f0", "primaryBorderColor": "#38bdf8", "secondaryColor": "#0f172a", "tertiaryColor": "#334155", "lineColor": "#64748b", "textColor": "#e2e8f0"}, "flowchart": {"htmlLabels": true, "curve": "basis", "nodeSpacing": 48, "rankSpacing": 64, "padding": 14, "diagramPadding": 10, "useMaxWidth": true}}}%%
flowchart LR
    EXTRACT_PIPELINE_5F350230("Extraction Pipeline<br/><small>PassOneEngine, IdeationalExtractor</small>")
    class EXTRACT_PIPELINE_5F350230 module;
    BUILD_GRAPH_321CBB04("Graph Build<br/><small>QuestionGraph, CrossDocumentGraph</small>")
    class BUILD_GRAPH_321CBB04 module;
    OUTPUTS_DOCS_ED82387C("Outputs & Docs<br/><small>Formatters, NarrativeGenerator</small>")
    class OUTPUTS_DOCS_ED82387C module;
    INGEST_CACHE_UPDATE_FF457338("Ingestion & Updates<br/><small>Pipeline, PassTwoEngine, PipelineCache</small>")
    class INGEST_CACHE_UPDATE_FF457338 module;
    SERVE_API_35EC8E86("Serving API<br/><small>Falcon API Server, ContextSynthesizer, Database</small>")
    class SERVE_API_35EC8E86 module;
    CLASSIFICATION_REGISTRY_D39798EE("Classification Registry<br/><small>SFL Types, DimensionConfig</small>")
    class CLASSIFICATION_REGISTRY_D39798EE module;
    TOPIC_MODELING_68E8584A("Topic Modeling<br/><small>TopicModeler</small>")
    class TOPIC_MODELING_68E8584A module;
    CHAT_SESSION_F300C146("Chat & Session<br/><small>Chat::App, Chat::Session</small>")
    class CHAT_SESSION_F300C146 module;
    TYPES_STRUCTS_4188A463("Types & Structs<br/><small>Dry::Struct definitions</small>")
    class TYPES_STRUCTS_4188A463 module;
    DATABASE_MIGRATIONS_37A83AD7("Database Migrations<br/><small>Sequel, pgvector</small>")
    class DATABASE_MIGRATIONS_37A83AD7 module;
    TENOR_TRACKING_A0CC376F("Tenor Tracking<br/><small>TenorTracker</small>")
    class TENOR_TRACKING_A0CC376F module;
    PASS_ONE_ENGINE_21E59C8B("Pass One Engine<br/><small>spaCy extraction</small>")
    class PASS_ONE_ENGINE_21E59C8B module;
    FALCON_API_496FAE07("Falcon API<br/><small>HTTP endpoints</small>")
    class FALCON_API_496FAE07 module;
    MARKDOWN_LOADING_2E669BB4("Markdown Loading<br/><small>MarkdownLoader</small>")
    class MARKDOWN_LOADING_2E669BB4 module;
    OTHER_D0941E68("Other<br/><small>CLI, Bootstrap, TUI</small>")
    class OTHER_D0941E68 module;
    OUTPUTS_DOCS_ED82387C -->|calls| BUILD_GRAPH_321CBB04
    BUILD_GRAPH_321CBB04 -->|calls| EXTRACT_PIPELINE_5F350230
    OUTPUTS_DOCS_ED82387C -->|contains| INGEST_CACHE_UPDATE_FF457338
    BUILD_GRAPH_321CBB04 -->|calls| INGEST_CACHE_UPDATE_FF457338
    MARKDOWN_LOADING_2E669BB4 -->|contains| OTHER_D0941E68
    MARKDOWN_LOADING_2E669BB4 -->|contains| OUTPUTS_DOCS_ED82387C
    MARKDOWN_LOADING_2E669BB4 -->|contains| EXTRACT_PIPELINE_5F350230
    BUILD_GRAPH_321CBB04 -->|method| OUTPUTS_DOCS_ED82387C
    EXTRACT_PIPELINE_5F350230 -->|contains| OTHER_D0941E68
    SERVE_API_35EC8E86 -->|method| INGEST_CACHE_UPDATE_FF457338
    INGEST_CACHE_UPDATE_FF457338 -->|calls| SERVE_API_35EC8E86
```

---

## Callflow Diagrams

Detailed call graphs for major subsystems.

| Diagram | Focus Area | Key Components |
|---------|------------|----------------|
| **callflow_1** | Extraction Pipeline | ThemeRhemeExtractor, IdeationalExtractor, Bootstrap |
| **callflow_2** | Graph Build | ConversationAnalyzer, QuestionGraph |
| **callflow_3** | Outputs & Docs | Formatters, NarrativeGenerator |
| **callflow_4** | Ingestion & Updates | Pipeline, PassTwoEngine, PipelineCache |
| **callflow_5** | Serving API | Falcon API Server, ContextSynthesizer, Database (fiber-safe pool) |
| **callflow_6** | Classification Registry | SFL Types, DimensionConfig |
| **callflow_7** | Topic Modeling | TopicModeler |
| **callflow_8** | Chat & Session | Chat::App, Chat::Session |
| **callflow_9** | Types & Structs | Dry::Struct definitions |
| **callflow_10** | Database Migrations | Sequel, pgvector |
| **callflow_11** | Tenor Tracking | TenorTracker |
| **callflow_12** | Pass One Engine | spaCy extraction |
| **callflow_13** | Falcon API | HTTP endpoints |
| **callflow_14** | Markdown Loading | MarkdownLoader |
| **callflow_15** | Other | CLI, Bootstrap, TUI |

---

## Legend

| Class | Color | Meaning |
|-------|-------|---------|
| `entry` | Yellow | Entry points (CLI, main) |
| `api` | Red | API endpoints |
| `async` | Purple | Async/background jobs |
| `klass` | Green | Core classes |
| `ui` | Pink | UI components |
| `module` | Blue | Module boundaries |
| `test` | Gray | Test files |
| `concept` | Dashed | Conceptual groupings |
| `function` | Cyan | Functions/methods |

---

## Graph Statistics

- **Nodes**: 915
- **Edges**: 1,246 (after removing low-confidence inferred edges)
- **Communities**: 64
- **Edge types**: All EXTRACTED (no INFERRED noise)

Stats above are from the last full semantic extraction. `callflow_5.mmd`
(Serving API) additionally carries a manually-added `ContextSynthesizer` +
`Database` subgraph (2026-07-03), sourced directly from a real
`graphify --update` run's `graph.json` — not fabricated — but not folded
back into the aggregate counts above, since that would require a full
re-extraction (semantic subagents across the whole corpus) rather than
the incremental, code-only AST update actually run. Run a full
`/graphify` pass to refresh these numbers precisely.
