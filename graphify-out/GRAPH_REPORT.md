# Graph Report - .  (2026-06-21)

## Corpus Check
- Corpus is ~23,239 words - fits in a single context window. You may not need a graph.

## Summary
- 370 nodes · 554 edges · 28 communities (19 shown, 9 thin omitted)
- Extraction: 83% EXTRACTED · 17% INFERRED · 0% AMBIGUOUS · INFERRED: 96 edges (avg confidence: 0.8)
- Token cost: 1,736 input · 3,247 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Bootstrap & Configuration|Bootstrap & Configuration]]
- [[_COMMUNITY_Pass Two Engine (LLM)|Pass Two Engine (LLM)]]
- [[_COMMUNITY_Narrative Generator|Narrative Generator]]
- [[_COMMUNITY_Correlation Analysis|Correlation Analysis]]
- [[_COMMUNITY_Conversation Analysis|Conversation Analysis]]
- [[_COMMUNITY_Topic Modeling|Topic Modeling]]
- [[_COMMUNITY_Documentation Analysis|Documentation Analysis]]
- [[_COMMUNITY_CLI Interface|CLI Interface]]
- [[_COMMUNITY_Context Synthesis|Context Synthesis]]
- [[_COMMUNITY_Pipeline Cache|Pipeline Cache]]
- [[_COMMUNITY_Hybrid Retriever|Hybrid Retriever]]
- [[_COMMUNITY_Embedding Storage|Embedding Storage]]
- [[_COMMUNITY_Theme Rheme Extractor|Theme Rheme Extractor]]
- [[_COMMUNITY_Clause Repository|Clause Repository]]
- [[_COMMUNITY_Formatters|Formatters]]
- [[_COMMUNITY_Pass One Engine (spaCy)|Pass One Engine (spaCy)]]
- [[_COMMUNITY_Database & Migrations|Database & Migrations]]
- [[_COMMUNITY_Ideational Extractor|Ideational Extractor]]
- [[_COMMUNITY_Types & Schemas|Types & Schemas]]
- [[_COMMUNITY_Markdown Loader|Markdown Loader]]
- [[_COMMUNITY_Cohesion Analysis|Cohesion Analysis]]
- [[_COMMUNITY_Pipeline Orchestration|Pipeline Orchestration]]

## God Nodes (most connected - your core abstractions)
1. `PassTwoEngine` - 21 edges
2. `PipelineCache` - 19 edges
3. `ConversationAnalyzer` - 15 edges
4. `MarkdownFormatter` - 14 edges
5. `DocumentationAnalyzer` - 13 edges
6. `IdeationalExtractor` - 13 edges
7. `Digest` - 10 edges
8. `parse()` - 9 edges
9. `MarkdownLoader` - 9 edges
10. `parse()` - 9 edges

## Surprising Connections (you probably didn't know these)
- `extract_with_llm()` --calls--> `parse()`  [INFERRED]
  experiments/05_llm_theme_extractor.rb → lib/sfl/compiler/cli.rb
- `call()` --calls--> `config()`  [INFERRED]
  lib/sfl/compiler/bootstrap.rb → lib/sfl/compiler.rb
- `connect()` --calls--> `config()`  [INFERRED]
  lib/sfl/compiler/storage/database.rb → lib/sfl/compiler.rb
- `setup_extensions()` --calls--> `logger()`  [INFERRED]
  lib/sfl/compiler/storage/database.rb → lib/sfl/compiler.rb
- `run_context()` --calls--> `config()`  [INFERRED]
  lib/sfl/compiler/cli.rb → lib/sfl/compiler.rb

## Import Cycles
- None detected.

## Communities (28 total, 9 thin omitted)

### Community 0 - "Bootstrap & Configuration"
Cohesion: 0.08
Nodes (19): api_key_for(), apply_request_timeout(), call(), configure_llm(), connect_db(), ThemeRhemeExtractor, BootstrapError, Configuration (+11 more)

### Community 1 - "Pass Two Engine (LLM)"
Cohesion: 0.13
Nodes (6): ClauseAnnotation, PassTwoEngine, SFLAnnotator, SFLBatchAnnotator, SFLBatchSignature, SFLSignature

### Community 2 - "Narrative Generator"
Cohesion: 0.10
Nodes (7): Digest, NarrativeGenerator, NarrativeSignature, SFLNarrator, run_narrate(), CSVFormatter, NarrativeFormatter

### Community 3 - "Correlation Analysis"
Cohesion: 0.10
Nodes (4): CorrelationAnalyzer, SpeakerProfiler, calculate_cohesion(), JSONFormatter

### Community 4 - "Conversation Analysis"
Cohesion: 0.13
Nodes (4): ConversationAnalyzer, parse(), run(), Pipeline

### Community 5 - "Topic Modeling"
Cohesion: 0.11
Nodes (6): assign_topics_to_turns(), cosine_distance(), tokenize(), topic_name(), TopicModeler, MarkdownLoader

### Community 6 - "Documentation Analysis"
Cohesion: 0.13
Nodes (3): DocumentationAnalyzer, TenorTracker, PassOneEngine

### Community 7 - "CLI Interface"
Cohesion: 0.11
Nodes (10): finish_report(), print_evidence(), run_context(), run_conversation(), run_documentation(), UsageError, write_narrative(), BaseFormatter (+2 more)

### Community 8 - "Context Synthesis"
Cohesion: 0.13
Nodes (5): ContextSynthesizer, SFLSynthesizer, SynthesisSignature, Embedder, HybridRetriever

### Community 10 - "Hybrid Retriever"
Cohesion: 0.11
Nodes (17): AnalysisResult, AnnotatedClause, CohesionMetrics, ConversationTurn, DispatchDecision, ExamplePassage, IdeationalPayload, InterpersonalPayload (+9 more)

### Community 13 - "Clause Repository"
Cohesion: 0.17
Nodes (3): build_spacy_analysis(), extract_with_llm(), ClauseRepository

### Community 14 - "Formatters"
Cohesion: 0.20
Nodes (10): CLI Interface Community, cli.rb, Conversation Analysis Community, Core Infrastructure Community, Migrator, NarrativeGenerator, parse(), PassTwoEngine (+2 more)

### Community 18 - "Types & Schemas"
Cohesion: 0.67
Nodes (3): build_callflow_html(), Shorten a file path for display., shorten_path()

## Knowledge Gaps
- **42 isolated node(s):** `ThemeRhemeSignature`, `Error`, `PassOneError`, `PassTwoError`, `ConfigurationError` (+37 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `parse()` connect `Conversation Analysis` to `Bootstrap & Configuration`, `Narrative Generator`, `CLI Interface`, `Pipeline Cache`, `Clause Repository`?**
  _High betweenness centrality (0.098) - this node is a cross-community bridge._
- **Why does `config()` connect `CLI Interface` to `Bootstrap & Configuration`?**
  _High betweenness centrality (0.091) - this node is a cross-community bridge._
- **Why does `PassTwoEngine` connect `Pass Two Engine (LLM)` to `CLI Interface`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **What connects `ThemeRhemeSignature`, `Error`, `PassOneError` to the rest of the system?**
  _43 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Bootstrap & Configuration` be split into smaller, more focused modules?**
  _Cohesion score 0.0761904761904762 - nodes in this community are weakly interconnected._
- **Should `Pass Two Engine (LLM)` be split into smaller, more focused modules?**
  _Cohesion score 0.12701612903225806 - nodes in this community are weakly interconnected._
- **Should `Narrative Generator` be split into smaller, more focused modules?**
  _Cohesion score 0.09852216748768473 - nodes in this community are weakly interconnected._