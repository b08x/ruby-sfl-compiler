# Graph Report - .  (2026-06-09)

## Corpus Check
- Corpus is ~8,656 words - fits in a single context window. You may not need a graph.

## Summary
- 149 nodes · 185 edges · 21 communities (12 shown, 9 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 22 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Core Compiler Configuration|Core Compiler Configuration]]
- [[_COMMUNITY_Type System & Storage|Type System & Storage]]
- [[_COMMUNITY_Pass Two Engine|Pass Two Engine]]
- [[_COMMUNITY_Ideational Extraction|Ideational Extraction]]
- [[_COMMUNITY_Pipeline Architecture & Concepts|Pipeline Architecture & Concepts]]
- [[_COMMUNITY_Hybrid Retrieval System|Hybrid Retrieval System]]
- [[_COMMUNITY_Pipeline Compilation Flow|Pipeline Compilation Flow]]
- [[_COMMUNITY_Markdown Loading|Markdown Loading]]
- [[_COMMUNITY_Clause Repository|Clause Repository]]
- [[_COMMUNITY_Embedding Repository|Embedding Repository]]
- [[_COMMUNITY_Claude Settings|Claude Settings]]
- [[_COMMUNITY_OpenCode Plugin|OpenCode Plugin]]
- [[_COMMUNITY_OpenCode Package|OpenCode Package]]
- [[_COMMUNITY_Documentation|Documentation]]

## God Nodes (most connected - your core abstractions)
1. `IdeationalExtractor` - 13 edges
2. `PassTwoEngine` - 10 edges
3. `MarkdownLoader` - 9 edges
4. `PassTwoEngine` - 9 edges
5. `Migrator` - 8 edges
6. `HybridRetriever` - 7 edges
7. `ClauseRepository` - 7 edges
8. `ClauseRepository` - 6 edges
9. `PassOneEngine` - 6 edges
10. `PassOneEngine` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Two-Pass Architecture` --rationale_for--> `PassOneEngine`  [EXTRACTED]
  docs/knowledge-base.md → lib/sfl/compiler/pass_one/pass_one_engine.rb
- `PassOneEngine` --references--> `ruby-spacy via PyCall`  [EXTRACTED]
  lib/sfl/compiler/pass_one/pass_one_engine.rb → docs/knowledge-base.md
- `IdeationalExtractor` --references--> `Lemma-Based Classification`  [EXTRACTED]
  lib/sfl/compiler/pass_one/ideational_extractor.rb → docs/knowledge-base.md
- `IdeationalExtractor` --references--> `SFL Metafunctions`  [EXTRACTED]
  lib/sfl/compiler/pass_one/ideational_extractor.rb → docs/knowledge-base.md
- `PassTwoEngine` --references--> `Circuit Breaker Pattern`  [EXTRACTED]
  lib/sfl/compiler/pass_two/pass_two_engine.rb → docs/knowledge-base.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Two-Pass Pipeline Flow** — markdown_loader, compiler_pipeline, pass_one_engine, ideational_extractor, pass_two_engine [EXTRACTED 1.00]
- **Storage Layer** — compiler_database, clause_repository, embedding_repository, compiler_types [EXTRACTED 1.00]
- **Retrieval Subsystem** — hybrid_retriever, clause_repository, embedding_repository [EXTRACTED 1.00]

## Communities (21 total, 9 thin omitted)

### Community 0 - "Core Compiler Configuration"
Cohesion: 0.09
Nodes (10): config(), Configuration, ConfigurationError, Error, logger(), PassOneError, PassTwoError, connect() (+2 more)

### Community 1 - "Type System & Storage"
Cohesion: 0.16
Nodes (16): ClauseRepository, Database, AnnotatedClause, DispatchDecision, IdeationalPayload, InterpersonalPayload, Participant, SyntacticClause (+8 more)

### Community 2 - "Pass Two Engine"
Cohesion: 0.22
Nodes (3): PassTwoEngine, SFLAnnotator, SFLSignature

### Community 4 - "Pipeline Architecture & Concepts"
Cohesion: 0.21
Nodes (11): Circuit Breaker Pattern, DSPy ChainOfThought, Lemma-Based Classification, ruby-spacy via PyCall, SFL Metafunctions, SFLSignature (typed DSPy signature), Two-Pass Architecture, IdeationalExtractor (+3 more)

### Community 10 - "Claude Settings"
Cohesion: 0.50
Nodes (3): enabledMcpjsonServers, permissions, allow

## Knowledge Gaps
- **26 isolated node(s):** `enabledMcpjsonServers`, `allow`, `$schema`, `plugin`, `@opencode-ai/plugin` (+21 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **9 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Pipeline` connect `Pipeline Compilation Flow` to `Pipeline Architecture & Concepts`?**
  _High betweenness centrality (0.230) - this node is a cross-community bridge._
- **Why does `PassTwoEngine` connect `Pipeline Architecture & Concepts` to `Type System & Storage`?**
  _High betweenness centrality (0.138) - this node is a cross-community bridge._
- **Why does `PassTwoEngine` connect `Pass Two Engine` to `Core Compiler Configuration`, `Pipeline Compilation Flow`?**
  _High betweenness centrality (0.128) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `PassTwoEngine` (e.g. with `types.rb` and `IdeationalExtractor`) actually correct?**
  _`PassTwoEngine` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `enabledMcpjsonServers`, `allow`, `$schema` to the rest of the system?**
  _29 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Core Compiler Configuration` be split into smaller, more focused modules?**
  _Cohesion score 0.08695652173913043 - nodes in this community are weakly interconnected._