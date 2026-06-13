# Graph Report - .  (2026-06-12)

## Corpus Check
- Corpus is ~18,418 words - fits in a single context window. You may not need a graph.

## Summary
- 266 nodes · 362 edges · 27 communities (13 shown, 14 thin omitted)
- Extraction: 87% EXTRACTED · 13% INFERRED · 0% AMBIGUOUS · INFERRED: 46 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Bootstrap & Config|Bootstrap & Config]]
- [[_COMMUNITY_ThemeRheme Experiments|Theme/Rheme Experiments]]
- [[_COMMUNITY_Conversation Analysis|Conversation Analysis]]
- [[_COMMUNITY_Correlation Analysis|Correlation Analysis]]
- [[_COMMUNITY_CLI Interface|CLI Interface]]
- [[_COMMUNITY_LLM Pass-Two Engine|LLM Pass-Two Engine]]
- [[_COMMUNITY_Ideational Extraction|Ideational Extraction]]
- [[_COMMUNITY_SFL Type Definitions|SFL Type Definitions]]
- [[_COMMUNITY_Hybrid Retrieval|Hybrid Retrieval]]
- [[_COMMUNITY_Markdown Output|Markdown Output]]
- [[_COMMUNITY_DSPy Annotation Engine|DSPy Annotation Engine]]
- [[_COMMUNITY_Markdown Loading|Markdown Loading]]
- [[_COMMUNITY_Pipeline Orchestrator|Pipeline Orchestrator]]
- [[_COMMUNITY_Speaker Profiling|Speaker Profiling]]
- [[_COMMUNITY_CSV Output|CSV Output]]
- [[_COMMUNITY_FCA Experiment|FCA Experiment]]
- [[_COMMUNITY_Embedding Storage|Embedding Storage]]
- [[_COMMUNITY_Callflow Export|Callflow Export]]
- [[_COMMUNITY_Directed Callflow|Directed Callflow]]
- [[_COMMUNITY_DSPy Theme Extractor|DSPy Theme Extractor]]

## God Nodes (most connected - your core abstractions)
1. `PassTwoEngine` - 18 edges
2. `IdeationalExtractor` - 13 edges
3. `ConversationAnalyzer` - 12 edges
4. `MarkdownFormatter` - 10 edges
5. `DocumentationAnalyzer` - 9 edges
6. `MarkdownLoader` - 9 edges
7. `SpeakerProfiler` - 8 edges
8. `Migrator` - 8 edges
9. `HybridRetriever` - 7 edges
10. `ClauseRepository` - 7 edges

## Surprising Connections (you probably didn't know these)
- `extract_with_llm()` --calls--> `parse()`  [INFERRED]
  experiments/05_llm_theme_extractor.rb → lib/sfl/compiler/cli.rb
- `configure_llm()` --calls--> `configure()`  [INFERRED]
  lib/sfl/compiler/bootstrap.rb → lib/sfl/compiler.rb
- `setup_extensions()` --calls--> `logger()`  [INFERRED]
  lib/sfl/compiler/storage/database.rb → lib/sfl/compiler.rb
- `call()` --calls--> `config()`  [INFERRED]
  lib/sfl/compiler/bootstrap.rb → lib/sfl/compiler.rb
- `connect()` --calls--> `config()`  [INFERRED]
  lib/sfl/compiler/storage/database.rb → lib/sfl/compiler.rb

## Import Cycles
- None detected.

## Communities (27 total, 14 thin omitted)

### Community 0 - "Bootstrap & Config"
Cohesion: 0.08
Nodes (18): api_key_for(), apply_request_timeout(), call(), configure_llm(), connect_db(), ThemeRhemeExtractor, BootstrapError, config() (+10 more)

### Community 1 - "Theme/Rheme Experiments"
Cohesion: 0.11
Nodes (6): build_spacy_analysis(), extract_with_llm(), ContextSynthesizer, SFLSynthesizer, SynthesisSignature, ClauseRepository

### Community 3 - "Correlation Analysis"
Cohesion: 0.14
Nodes (3): CorrelationAnalyzer, DocumentationAnalyzer, TenorTracker

### Community 4 - "CLI Interface"
Cohesion: 0.13
Nodes (10): finish_report(), parse(), print_evidence(), run(), run_context(), run_conversation(), run_documentation(), UsageError (+2 more)

### Community 7 - "SFL Type Definitions"
Cohesion: 0.15
Nodes (12): AnalysisResult, AnnotatedClause, ConversationTurn, DispatchDecision, IdeationalPayload, InterpersonalPayload, Participant, SpeakerProfile (+4 more)

### Community 10 - "DSPy Annotation Engine"
Cohesion: 0.22
Nodes (5): ClauseAnnotation, SFLAnnotator, SFLBatchAnnotator, SFLBatchSignature, SFLSignature

## Knowledge Gaps
- **23 isolated node(s):** `ThemeRhemeSignature`, `Error`, `PassOneError`, `PassTwoError`, `ConfigurationError` (+18 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **14 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `parse()` connect `CLI Interface` to `Bootstrap & Config`, `Theme/Rheme Experiments`, `Conversation Analysis`?**
  _High betweenness centrality (0.113) - this node is a cross-community bridge._
- **Why does `PassTwoEngine` connect `LLM Pass-Two Engine` to `Bootstrap & Config`, `DSPy Annotation Engine`?**
  _High betweenness centrality (0.098) - this node is a cross-community bridge._
- **What connects `ThemeRhemeSignature`, `Error`, `PassOneError` to the rest of the system?**
  _23 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Bootstrap & Config` be split into smaller, more focused modules?**
  _Cohesion score 0.07657657657657657 - nodes in this community are weakly interconnected._
- **Should `Theme/Rheme Experiments` be split into smaller, more focused modules?**
  _Cohesion score 0.10952380952380952 - nodes in this community are weakly interconnected._
- **Should `Conversation Analysis` be split into smaller, more focused modules?**
  _Cohesion score 0.14736842105263157 - nodes in this community are weakly interconnected._
- **Should `Correlation Analysis` be split into smaller, more focused modules?**
  _Cohesion score 0.1368421052631579 - nodes in this community are weakly interconnected._