# Graph Report - .  (2026-06-12)

## Corpus Check
- Corpus is ~19,905 words - fits in a single context window. You may not need a graph.

## Summary
- 322 nodes · 429 edges · 34 communities (19 shown, 15 thin omitted)
- Extraction: 87% EXTRACTED · 13% INFERRED · 0% AMBIGUOUS · INFERRED: 55 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Bootstrap & Configuration|Bootstrap & Configuration]]
- [[_COMMUNITY_Documentation Analysis|Documentation Analysis]]
- [[_COMMUNITY_Conversation Analysis|Conversation Analysis]]
- [[_COMMUNITY_Pipeline Orchestration|Pipeline Orchestration]]
- [[_COMMUNITY_Narrative Generation|Narrative Generation]]
- [[_COMMUNITY_CLI Interface|CLI Interface]]
- [[_COMMUNITY_ThemeRheme Extraction|Theme/Rheme Extraction]]
- [[_COMMUNITY_Data Types|Data Types]]
- [[_COMMUNITY_Ideational Extraction|Ideational Extraction]]
- [[_COMMUNITY_Graph Query Results|Graph Query Results]]
- [[_COMMUNITY_Hybrid Retrieval|Hybrid Retrieval]]
- [[_COMMUNITY_Markdown Formatting|Markdown Formatting]]
- [[_COMMUNITY_Pass Two Engine|Pass Two Engine]]
- [[_COMMUNITY_Speaker Profiling|Speaker Profiling]]
- [[_COMMUNITY_CSV Formatting|CSV Formatting]]
- [[_COMMUNITY_JSON Formatting|JSON Formatting]]
- [[_COMMUNITY_FCA Experiments|FCA Experiments]]
- [[_COMMUNITY_Pass One Engine|Pass One Engine]]
- [[_COMMUNITY_Embedding Storage|Embedding Storage]]
- [[_COMMUNITY_Narrative Pipeline|Narrative Pipeline]]
- [[_COMMUNITY_Callflow Export|Callflow Export]]
- [[_COMMUNITY_LLM Configuration|LLM Configuration]]
- [[_COMMUNITY_Database Connection|Database Connection]]
- [[_COMMUNITY_Context Synthesis|Context Synthesis]]
- [[_COMMUNITY_Directed Callflow|Directed Callflow]]
- [[_COMMUNITY_DSPy Theme Experiments|DSPy Theme Experiments]]

## God Nodes (most connected - your core abstractions)
1. `PassTwoEngine` - 18 edges
2. `IdeationalExtractor` - 13 edges
3. `ConversationAnalyzer` - 12 edges
4. `parse()` - 11 edges
5. `Digest` - 10 edges
6. `MarkdownFormatter` - 10 edges
7. `DocumentationAnalyzer` - 9 edges
8. `MarkdownLoader` - 9 edges
9. `SpeakerProfiler` - 8 edges
10. `parse()` - 8 edges

## Surprising Connections (you probably didn't know these)
- `extract_with_llm()` --calls--> `parse()`  [INFERRED]
  experiments/05_llm_theme_extractor.rb → lib/sfl/compiler/cli.rb
- `configure()` --calls--> `configure_llm()`  [INFERRED]
  lib/sfl/compiler.rb → lib/sfl/compiler/bootstrap.rb
- `logger()` --calls--> `setup_extensions()`  [INFERRED]
  lib/sfl/compiler.rb → lib/sfl/compiler/storage/database.rb
- `config()` --calls--> `call()`  [INFERRED]
  lib/sfl/compiler.rb → lib/sfl/compiler/bootstrap.rb
- `config()` --calls--> `connect()`  [INFERRED]
  lib/sfl/compiler.rb → lib/sfl/compiler/storage/database.rb

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **parse() bridges 4 communities** — parse_function, conversation_analysis_community, cli_interface_community, retrieval_synthesis_community, core_infrastructure_community [EXTRACTED 1.00]
- **Narrative generation pipeline** — narrativegenerator_component, generate_method, from_result_method, write_narrative_method [EXTRACTED 1.00]

## Communities (34 total, 15 thin omitted)

### Community 0 - "Bootstrap & Configuration"
Cohesion: 0.07
Nodes (19): api_key_for(), apply_request_timeout(), call(), configure_llm(), connect_db(), ThemeRhemeExtractor, BootstrapError, config() (+11 more)

### Community 1 - "Documentation Analysis"
Cohesion: 0.11
Nodes (3): DocumentationAnalyzer, TenorTracker, MarkdownLoader

### Community 2 - "Conversation Analysis"
Cohesion: 0.13
Nodes (5): ConversationAnalyzer, CorrelationAnalyzer, parse(), run(), Why parse() bridges 4 communities

### Community 4 - "Narrative Generation"
Cohesion: 0.13
Nodes (6): Digest, NarrativeGenerator, NarrativeSignature, SFLNarrator, run_narrate(), NarrativeFormatter

### Community 5 - "CLI Interface"
Cohesion: 0.14
Nodes (9): finish_report(), print_evidence(), run_context(), run_conversation(), run_documentation(), UsageError, write_narrative(), BaseFormatter (+1 more)

### Community 6 - "Theme/Rheme Extraction"
Cohesion: 0.12
Nodes (6): build_spacy_analysis(), extract_with_llm(), ContextSynthesizer, SFLSynthesizer, SynthesisSignature, ClauseRepository

### Community 7 - "Data Types"
Cohesion: 0.14
Nodes (13): AnalysisResult, AnnotatedClause, ConversationTurn, DispatchDecision, IdeationalPayload, InterpersonalPayload, NarrativeReport, Participant (+5 more)

### Community 9 - "Graph Query Results"
Cohesion: 0.17
Nodes (7): Betweenness Centrality (0.206), CLI Interface (Community 4), cli.rb, Conversation Analysis (Community 3), Core Infrastructure (Community 0), parse(), Retrieval and Synthesis (Community 5)

### Community 12 - "Pass Two Engine"
Cohesion: 0.22
Nodes (5): ClauseAnnotation, SFLAnnotator, SFLBatchAnnotator, SFLBatchSignature, SFLSignature

### Community 20 - "Callflow Export"
Cohesion: 0.67
Nodes (3): build_callflow_html(), Shorten a file path for display., shorten_path()

### Community 21 - "LLM Configuration"
Cohesion: 0.67
Nodes (3): bootstrap.rb, configure_llm(), PassTwoEngine

## Knowledge Gaps
- **35 isolated node(s):** `ThemeRhemeSignature`, `Error`, `PassOneError`, `PassTwoError`, `ConfigurationError` (+30 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **15 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `parse()` connect `Conversation Analysis` to `Bootstrap & Configuration`, `Narrative Generation`, `CLI Interface`, `Theme/Rheme Extraction`?**
  _High betweenness centrality (0.176) - this node is a cross-community bridge._
- **Why does `run_narrate()` connect `Narrative Generation` to `Conversation Analysis`, `CLI Interface`?**
  _High betweenness centrality (0.101) - this node is a cross-community bridge._
- **What connects `ThemeRhemeSignature`, `Error`, `PassOneError` to the rest of the system?**
  _36 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Bootstrap & Configuration` be split into smaller, more focused modules?**
  _Cohesion score 0.07396870554765292 - nodes in this community are weakly interconnected._
- **Should `Documentation Analysis` be split into smaller, more focused modules?**
  _Cohesion score 0.1076923076923077 - nodes in this community are weakly interconnected._
- **Should `Conversation Analysis` be split into smaller, more focused modules?**
  _Cohesion score 0.13043478260869565 - nodes in this community are weakly interconnected._
- **Should `Narrative Generation` be split into smaller, more focused modules?**
  _Cohesion score 0.12987012987012986 - nodes in this community are weakly interconnected._