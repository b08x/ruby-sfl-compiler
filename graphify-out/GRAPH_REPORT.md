# Graph Report - .  (2026-06-11)

## Corpus Check
- Corpus is ~18,992 words - fits in a single context window. You may not need a graph.

## Summary
- 252 nodes · 304 edges · 31 communities (15 shown, 16 thin omitted)
- Extraction: 84% EXTRACTED · 16% INFERRED · 0% AMBIGUOUS · INFERRED: 50 edges (avg confidence: 0.82)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Research & Experiments|Research & Experiments]]
- [[_COMMUNITY_Analysis Engine|Analysis Engine]]
- [[_COMMUNITY_LLM Tools & Storage|LLM Tools & Storage]]
- [[_COMMUNITY_Pipeline Docs & Overview|Pipeline Docs & Overview]]
- [[_COMMUNITY_Pass Two Engine|Pass Two Engine]]
- [[_COMMUNITY_Ideational Extractor|Ideational Extractor]]
- [[_COMMUNITY_DSPy Provider Config|DSPy Provider Config]]
- [[_COMMUNITY_Pipeline Orchestration|Pipeline Orchestration]]
- [[_COMMUNITY_Type System|Type System]]
- [[_COMMUNITY_Configuration & Errors|Configuration & Errors]]
- [[_COMMUNITY_Hybrid Retriever|Hybrid Retriever]]
- [[_COMMUNITY_Clause Repository|Clause Repository]]
- [[_COMMUNITY_Markdown Loader|Markdown Loader]]
- [[_COMMUNITY_Speaker Profiler|Speaker Profiler]]
- [[_COMMUNITY_CSV Formatter|CSV Formatter]]
- [[_COMMUNITY_Markdown Formatter|Markdown Formatter]]
- [[_COMMUNITY_FCA Proof of Concept|FCA Proof of Concept]]
- [[_COMMUNITY_JSON Formatter|JSON Formatter]]
- [[_COMMUNITY_Base Formatter|Base Formatter]]
- [[_COMMUNITY_Embedding Repository|Embedding Repository]]
- [[_COMMUNITY_AILLM Explorations|AI/LLM Explorations]]
- [[_COMMUNITY_Reflective Journal|Reflective Journal]]
- [[_COMMUNITY_DSPy Theme Extractor|DSPy Theme Extractor]]
- [[_COMMUNITY_pgvector Storage|pgvector Storage]]

## God Nodes (most connected - your core abstractions)
1. `IdeationalExtractor` - 13 edges
2. `PassTwoEngine` - 10 edges
3. `MarkdownLoader` - 9 edges
4. `ConversationAnalyzer` - 9 edges
5. `SpeakerProfiler` - 8 edges
6. `Migrator` - 8 edges
7. `HybridRetriever` - 7 edges
8. `SFL Analysis of Notebook Collection` - 7 edges
9. `Pass 2: DSPy LLM interpersonal annotation` - 7 edges
10. `CSVFormatter` - 6 edges

## Surprising Connections (you probably didn't know these)
- `Pass 2 LLM Integration` --describes_issue_in--> `Pass 2: DSPy LLM interpersonal annotation`  [INFERRED]
  KNOWN_ISSUES.md → SESSION_SUMMARY.md
- `Pass 2: DSPy LLM interpersonal annotation` --uses--> `DSPy::ChainOfThought`  [INFERRED]
  SESSION_SUMMARY.md → KNOWN_ISSUES.md
- `Pass 1: spaCy syntactic parsing` --uses--> `spaCy en_core_web_sm`  [INFERRED]
  SESSION_SUMMARY.md → KNOWN_ISSUES.md
- `topic_clustering script` --related_to--> `FCA Pattern Discovery`  [INFERRED]
  NOTEBOOK_ANALYSIS_PLAN.md → experiments/RESULTS.md
- `CohesionAnalyzer class` --validated_by--> `Cohesion Correlation`  [INFERRED]
  RESEARCH_APPLICATION_PLAN.md → experiments/RESULTS.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **SFL Analysis Pipeline** — SESSION_Pass1_spaCy_syntactic_parsing, SESSION_Pass2_DSPy_LLM_interpersonal_annotation, USAGE_Tenor_Formality, USAGE_Modality_Certainty, USAGE_Process_Types [INFERRED 0.85]
- **Experimental Validation Framework** — EXPERIMENTS_FCA_Pattern_Discovery, EXPERIMENTS_ID3_Feature_Importance, EXPERIMENTS_Cohesion_Correlation, EXPERIMENTS_DSPy_Theme_Rheme_Extraction, EXPERIMENTS_Concept_Lattice, EXPERIMENTS_Attribute_Implications [EXTRACTED 1.00]
- **Research Implementation Components** — RESEARCH_TextualExtractor_class, RESEARCH_CohesionAnalyzer_class, RESEARCH_FCAAdapter_class, RESEARCH_SpeakerClassifier_class, RESEARCH_InsightGenerator_class [INFERRED 0.80]

## Communities (31 total, 16 thin omitted)

### Community 0 - "Research & Experiments"
Cohesion: 0.11
Nodes (21): Attribute Implications, Cohesion Correlation, Concept Lattice, DSPy Theme/Rheme Extraction, FCA Pattern Discovery, ID3 Feature Importance, Theme/Rheme Extraction (spaCy), topic_clustering script (+13 more)

### Community 1 - "Analysis Engine"
Cohesion: 0.13
Nodes (3): CorrelationAnalyzer, TenorTracker, ConversationAnalyzer

### Community 2 - "LLM Tools & Storage"
Cohesion: 0.15
Nodes (5): ThemeRhemeExtractor, logger(), connect(), Migrator, setup_extensions()

### Community 3 - "Pipeline Docs & Overview"
Cohesion: 0.16
Nodes (17): Circuit breaker, Pass 2 LLM Integration, ruby-spacy gem, spaCy en_core_web_sm, InsightGenerator class, SFL Analysis of Notebook Collection, batch_analyze_collection script, temporal_analysis script (+9 more)

### Community 4 - "Pass Two Engine"
Cohesion: 0.22
Nodes (3): PassTwoEngine, SFLAnnotator, SFLSignature

### Community 6 - "DSPy Provider Config"
Cohesion: 0.15
Nodes (13): DSPy::ChainOfThought, OpenRouter, SFLAnnotator class, dspy gem, dspy-openai gem, markdown_to_jsonl converter, DSPY_PROVIDER, Google Gemini (Native) (+5 more)

### Community 8 - "Type System"
Cohesion: 0.17
Nodes (11): AnalysisResult, AnnotatedClause, ConversationTurn, DispatchDecision, IdeationalPayload, InterpersonalPayload, Participant, SpeakerProfile (+3 more)

### Community 9 - "Configuration & Errors"
Cohesion: 0.17
Nodes (6): config(), Configuration, ConfigurationError, Error, PassOneError, PassTwoError

## Knowledge Gaps
- **40 isolated node(s):** `ThemeRhemeSignature`, `Error`, `PassOneError`, `PassTwoError`, `ConfigurationError` (+35 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **16 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ConversationAnalyzer` connect `Analysis Engine` to `LLM Tools & Storage`?**
  _High betweenness centrality (0.057) - this node is a cross-community bridge._
- **Why does `logger()` connect `LLM Tools & Storage` to `Configuration & Errors`, `Pass Two Engine`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Why does `PassTwoEngine` connect `Pass Two Engine` to `Configuration & Errors`, `Pipeline Orchestration`?**
  _High betweenness centrality (0.036) - this node is a cross-community bridge._
- **What connects `ThemeRhemeSignature`, `Error`, `PassOneError` to the rest of the system?**
  _40 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Research & Experiments` be split into smaller, more focused modules?**
  _Cohesion score 0.10952380952380952 - nodes in this community are weakly interconnected._
- **Should `Analysis Engine` be split into smaller, more focused modules?**
  _Cohesion score 0.13450292397660818 - nodes in this community are weakly interconnected._