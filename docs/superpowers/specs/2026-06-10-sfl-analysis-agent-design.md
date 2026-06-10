# SFL Analysis Agent & Skill — Design Specification

**Date**: 2026-06-10  
**Status**: Approved  
**Author**: Claude (Sonnet 4.5) + Robert Pannick

---

## Overview

A Claude Code agent and skill that generates custom analysis scripts using the SFL (Systemic Functional Linguistics) compiler framework. The agent understands SFL capabilities and creates tailored scripts for analyzing conversations, documentation, and general text—with a future path toward multimodal analysis (audio, images, video).

**Core Value Proposition**: Transform natural language analysis requests into executable SFL scripts that extract rhetorical patterns invisible to traditional NLP tools.

---

## Problem Statement

The SFL compiler framework provides powerful linguistic analysis capabilities (tenor tracking, field evolution, modality filtering), but requires Ruby programming knowledge to use effectively. Users need:

1. **Easy access** to SFL analysis without writing boilerplate code
2. **Domain-specific scripts** for common patterns (conversations, docs, context)
3. **Customizable analysis** that combines multiple SFL features
4. **Interpretable output** in multiple formats (CSV, JSON, Markdown, HTML)
5. **Extensibility** for future multimodal inputs (audio transcripts, OCR'd images)

---

## Architecture

### High-Level Design

```
┌──────────────────────────────────────────────────────────┐
│  SFL Analysis Agent (sfl-analyzer)                       │
│  - Understands SFL framework capabilities                │
│  - Generates analysis scripts from natural language       │
│  - Template library for common patterns                   │
│  - Extensible for multimodal (audio/image) future        │
└──────────────────────┬───────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────┐
│  Skill: /sfl-analyze                                      │
│  - analyze-conversation <path> [options]                  │
│  - analyze-documentation <path> [options]                 │
│  - analyze-context <query> [options]                      │
│  - generate-script <description>                          │
└──────────────────────┬───────────────────────────────────┘
                       │
         ┌─────────────┴──────────────┬──────────────┐
         ▼                            ▼              ▼
┌─────────────────┐        ┌─────────────────┐  ┌─────────────┐
│ Template Scripts│        │Custom Generated │  │Output       │
│                 │        │Scripts          │  │Formatters   │
│- convo_analysis │        │                 │  │- CSV        │
│- doc_audit      │        │User-defined     │  │- JSON       │
│- context_extract│        │                 │  │- Markdown   │
│- (multimodal)   │        │                 │  │- Viz (HTML) │
└────────┬────────┘        └────────┬────────┘  └──────┬──────┘
         │                          │                  │
         └──────────────────────────┴──────────────────┘
                                    ▼
                        ┌──────────────────────┐
                        │ SFL Core Pipeline     │
                        │ (sfl-compiler gem)    │
                        │                       │
                        │ - PassOneEngine       │
                        │ - PassTwoEngine       │
                        │ - HybridRetriever     │
                        │ - Database (PG)       │
                        └──────────────────────┘
```

### Components

#### 1. SFL Analysis Agent

A Claude Code agent with specialized knowledge:

- **SFL Framework Expertise**: Understands Pass 1/2 pipeline, data model, retrieval API
- **Script Generation**: Produces custom Ruby scripts from natural language descriptions
- **Template Library**: Pre-built scripts for common analysis patterns
- **Domain Knowledge**: Conversation analysis, documentation auditing, context extraction

**Agent Configuration** (`.claude/agents/sfl-analyzer.md`):
```yaml
name: sfl-analyzer
description: Generates analysis scripts using the SFL compiler framework
model: sonnet
tools: [Read, Write, Bash, Edit, Agent]
skills: [sfl-analyze]
```

#### 2. Skill: `/sfl-analyze`

User-facing command interface with subcommands:

**Usage**:
```bash
# Analyze conversation (JSONL format)
/sfl-analyze conversation path/to/chat.jsonl --track-tenor --track-field --correlate

# Analyze documentation (Markdown)
/sfl-analyze documentation path/to/docs/ --audit-certainty --extract-requirements

# Analyze context (generic text)
/sfl-analyze context "query terms" --filters "min_modality:0.7,mood:imperative"

# Generate custom script
/sfl-analyze generate-script "Find hedged language in technical docs and export to CSV"
```

**Skill Structure** (`.claude/skills/sfl-analyze/SKILL.md`):
- Subcommand routing
- Parameter validation
- Script template selection
- Output format handling

#### 3. Template Scripts

Pre-built Ruby scripts in `scripts/sfl_analysis/`:

**3.1 Conversation Analysis** (`analyze_conversation_tenor_field.rb`)
- Parses JSONL chat logs
- Tracks tenor evolution (formality shifts)
- Maps field evolution (topic/process changes)
- Correlates tenor ↔ field patterns
- Generates CSV + JSON + Markdown + HTML outputs

**3.2 Documentation Audit** (`audit_documentation.rb`)
- Loads Markdown documentation
- Detects certainty mismatches (hedged language in critical sections)
- Extracts imperative statements (requirements)
- Identifies tone inconsistencies
- Outputs structured report

**3.3 Context Extraction** (`extract_context.rb`)
- Queries SFL database with custom filters
- Retrieves clauses matching rhetorical criteria
- Exports annotated results
- Supports hybrid (semantic + keyword) retrieval

#### 4. Output Formatters

Modular formatters for different use cases:

- **CSV**: Spreadsheet-compatible turn-by-turn data
- **JSON**: Structured data for APIs/programmatic access
- **Markdown**: Human-readable reports with insights
- **HTML**: Interactive dashboards with visualizations

Each formatter implements a common interface:
```ruby
module SFL::Compiler::Formatters
  class BaseFormatter
    def initialize(analysis_result)
      @result = analysis_result
    end
    
    def render
      raise NotImplementedError
    end
  end
  
  class CSVFormatter < BaseFormatter; end
  class JSONFormatter < BaseFormatter; end
  class MarkdownFormatter < BaseFormatter; end
  class HTMLFormatter < BaseFormatter; end
end
```

---

## Conversation Analysis Script (Detailed Design)

### Input Format

JSONL file with conversation turns:
```json
{"name":"Robert","is_user":true,"send_date":"August 29, 2025 11:19am","mes":"Message text...","extra":{...}}
{"name":"Steve","is_user":false,"send_date":"August 29, 2025 11:20am","mes":"Response text...","extra":{...}}
```

### Processing Pipeline

```ruby
# Pseudo-code flow
1. Load & Parse JSONL
   - Read file line by line
   - Parse JSON objects
   - Extract: speaker, timestamp, message, metadata
   - Build ConversationTurn objects

2. SFL Compilation
   pipeline = SFL::Compiler::Pipeline.new(db: db)
   
   conversation.turns.each do |turn|
     annotated_clauses = pipeline.compile(
       turn.message_text,
       document_id: "conversation:#{conversation_id}:turn:#{turn.id}",
       store: true,
       embed: true
     )
     
     turn.clauses = annotated_clauses
   end

3. Aggregation (Turn-Level Metrics)
   turn.avg_tenor = turn.clauses.map(&:interpersonal.tenor).mean
   turn.avg_modality = turn.clauses.map(&:interpersonal.modality_weight).mean
   turn.dominant_mood = turn.clauses.map(&:interpersonal.mood).mode
   turn.process_types = turn.clauses.group_by(&:ideational.process_type).transform_values(&:count)

4. Tenor Analysis
   - Calculate per-speaker averages
   - Detect significant shifts (|Δtenor| > 0.15 between adjacent turns)
   - Track rolling averages (window=3)
   - Identify tenor patterns (increasing, decreasing, stable)

5. Field Evolution Analysis
   - Extract dominant process types per turn
   - Cluster turns by semantic similarity (embedding cosine distance)
   - Build topic timeline (topic change = cosine similarity < 0.7)
   - Track participant evolution (key entities mentioned)

6. Correlation Analysis
   - Group clauses by process_type → calculate avg_tenor
   - Correlation matrix: {process_type => {avg_tenor, avg_modality}}
   - Speaker-specific patterns: Robert's mental processes vs Steve's verbal processes

7. Insight Generation
   - Compare speaker profiles (avg tenor, variance, dominant moods)
   - Find largest tenor shifts with context
   - Identify process type preferences per speaker
   - Detect correlations (e.g., "mental processes = casual tenor")

8. Output Generation
   - CSVFormatter.new(result).render → conversation_analysis.csv
   - JSONFormatter.new(result).render → conversation_analysis.json
   - MarkdownFormatter.new(result).render → conversation_analysis.md
   - HTMLFormatter.new(result).render → conversation_analysis.html
```

### Data Structures

```ruby
# Core data types
ConversationTurn = Struct.new(
  :turn_id,           # Integer (1-indexed)
  :speaker,           # String ("Robert", "Steve")
  :timestamp,         # DateTime
  :message_text,      # String (original message)
  :clauses,           # Array<Types::AnnotatedClause>
  :avg_tenor,         # Float (0.0-1.0, avg across clauses)
  :avg_modality,      # Float (0.0-1.0)
  :dominant_mood,     # String (most common mood in turn)
  :process_types,     # Hash {process_type => count}
  :participants,      # Array<String> (key entities/participants)
  :tenor_shift        # Float (vs previous turn, nil for turn 1)
)

SpeakerProfile = Struct.new(
  :speaker_name,           # String
  :turn_count,             # Integer
  :avg_tenor,              # Float
  :tenor_range,            # [min, max]
  :tenor_variance,         # Float
  :avg_modality,           # Float
  :mood_distribution,      # Hash {mood => proportion}
  :dominant_processes,     # Hash {process_type => count}
  :preferred_participants  # Array<String> (most mentioned entities)
)

AnalysisResult = Struct.new(
  :conversation_metadata,  # Hash {duration, turn_count, speakers, date}
  :turns,                  # Array<ConversationTurn>
  :speaker_profiles,       # Hash {speaker_name => SpeakerProfile}
  :tenor_timeline,         # Array<{timestamp, tenor, speaker}>
  :field_evolution,        # Array<{timestamp, dominant_process, topics}>
  :correlations,           # Hash {process_type => {avg_tenor, avg_modality}}
  :insights                # Array<String> (generated observations)
)
```

### Analysis Features

#### Feature 1: Tenor Shift Detection

Identify significant formality changes between turns:

```ruby
def detect_tenor_shifts(turns, threshold: 0.15)
  shifts = []
  turns.each_cons(2) do |prev_turn, curr_turn|
    delta = curr_turn.avg_tenor - prev_turn.avg_tenor
    if delta.abs > threshold
      shifts << {
        turn_id: curr_turn.turn_id,
        from_speaker: prev_turn.speaker,
        to_speaker: curr_turn.speaker,
        from_tenor: prev_turn.avg_tenor,
        to_tenor: curr_turn.avg_tenor,
        delta: delta,
        direction: delta > 0 ? "more formal" : "less formal"
      }
    end
  end
  shifts
end
```

**Example Output**:
```
Turn 2: Robert (0.32) → Steve (0.78) = +0.46 (more formal)
Context: "Robert shares personal vulnerability; Steve responds with sarcastic formality"
```

#### Feature 2: Speaker Profiling

Calculate aggregated metrics per speaker:

```ruby
def build_speaker_profile(speaker_name, turns)
  speaker_turns = turns.select { |t| t.speaker == speaker_name }
  
  SpeakerProfile.new(
    speaker_name: speaker_name,
    turn_count: speaker_turns.count,
    avg_tenor: speaker_turns.map(&:avg_tenor).mean,
    tenor_range: [speaker_turns.map(&:avg_tenor).min, speaker_turns.map(&:avg_tenor).max],
    tenor_variance: speaker_turns.map(&:avg_tenor).variance,
    avg_modality: speaker_turns.map(&:avg_modality).mean,
    mood_distribution: calculate_mood_distribution(speaker_turns),
    dominant_processes: aggregate_process_types(speaker_turns),
    preferred_participants: extract_frequent_participants(speaker_turns, top: 10)
  )
end
```

**Example Output**:
```
Robert: avg_tenor=0.38 (casual), variance=0.14 (high), mental_processes=52%
Steve:  avg_tenor=0.76 (formal), variance=0.05 (low), verbal_processes=41%
```

#### Feature 3: Topic Clustering

Group turns by semantic similarity:

```ruby
def cluster_topics(turns, similarity_threshold: 0.7)
  topics = []
  current_topic = { turns: [turns.first], start_turn: 1 }
  
  turns.each_cons(2) do |prev_turn, curr_turn|
    # Calculate embedding similarity between turns
    similarity = cosine_similarity(
      prev_turn.clauses.first.embedding,
      curr_turn.clauses.first.embedding
    )
    
    if similarity < similarity_threshold
      # Topic shift detected
      topics << current_topic
      current_topic = { turns: [curr_turn], start_turn: curr_turn.turn_id }
    else
      current_topic[:turns] << curr_turn
    end
  end
  
  topics << current_topic
  topics
end
```

**Example Output**:
```
Topic 1 (Turns 1-4):  Imposter syndrome, self-doubt (mental processes=62%)
Topic 2 (Turns 5-8):  Industry pressures, obsolescence (material/verbal processes=58%)
Topic 3 (Turns 9-12): Perfectionism vs shipping (relational processes=41%)
```

#### Feature 4: Process Type Correlation

Correlate process types with tenor/modality:

```ruby
def correlate_process_tenor(turns)
  all_clauses = turns.flat_map(&:clauses)
  
  all_clauses.group_by { |c| c.ideational.process_type }.transform_values do |clauses|
    {
      count: clauses.count,
      avg_tenor: clauses.map { |c| c.interpersonal.tenor }.mean,
      avg_modality: clauses.map { |c| c.interpersonal.modality_weight }.mean,
      tenor_stddev: clauses.map { |c| c.interpersonal.tenor }.stddev
    }
  end
end
```

**Example Output**:
```
mental:     avg_tenor=0.34, avg_modality=0.42 (introspection = casual, hedged)
verbal:     avg_tenor=0.71, avg_modality=0.79 (commentary = formal, assertive)
material:   avg_tenor=0.52, avg_modality=0.61 (action talk = mid-formality)
relational: avg_tenor=0.48, avg_modality=0.54 (definitions = neutral)
```

---

## Output Formats

### CSV Export

**File**: `conversation_analysis.csv`

**Columns**:
```
turn_id, speaker, timestamp, message_preview, avg_tenor, avg_modality, 
dominant_mood, process_counts, participants, tenor_shift
```

**Example Rows**:
```csv
1,Robert,2025-08-29 11:19,"Ah you know it's kinda funny",0.32,0.45,declarative,"mental:4 relational:2","I career learning",0.0
2,Steve,2025-08-29 11:20,"Oh please spare me the existential",0.78,0.82,exclamative,"verbal:5 material:3","you crisis engineer",+0.46
3,Robert,2025-08-29 11:33,"Well you're not wrong",0.41,0.38,declarative,"mental:3 relational:1","I you feedback loop",-0.37
```

**Use Case**: Import into Excel/Google Sheets for pivot tables, charts, filtering

---

### JSON Export

**File**: `conversation_analysis.json`

**Structure**:
```json
{
  "metadata": {
    "conversation_id": "steve-oliver-2025-08-29",
    "duration_minutes": 19,
    "turn_count": 28,
    "speakers": ["Robert", "Steve"],
    "analyzed_at": "2026-06-10T14:32:15Z",
    "sfl_compiler_version": "0.1.0"
  },
  "speaker_profiles": {
    "Robert": {
      "turn_count": 14,
      "avg_tenor": 0.38,
      "tenor_range": [0.22, 0.61],
      "tenor_variance": 0.14,
      "avg_modality": 0.42,
      "mood_distribution": {
        "declarative": 0.72,
        "interrogative": 0.18,
        "imperative": 0.07,
        "exclamative": 0.03
      },
      "dominant_processes": {
        "mental": 45,
        "relational": 22,
        "material": 18,
        "verbal": 12,
        "behavioral": 3
      }
    },
    "Steve": {
      "turn_count": 14,
      "avg_tenor": 0.76,
      "tenor_range": [0.68, 0.84],
      "tenor_variance": 0.05,
      "avg_modality": 0.79,
      "mood_distribution": {
        "declarative": 0.54,
        "exclamative": 0.28,
        "interrogative": 0.12,
        "imperative": 0.06
      },
      "dominant_processes": {
        "verbal": 38,
        "material": 25,
        "mental": 19,
        "relational": 16,
        "behavioral": 2
      }
    }
  },
  "correlations": {
    "process_tenor": {
      "mental": 0.34,
      "material": 0.52,
      "verbal": 0.71,
      "relational": 0.48,
      "behavioral": 0.41,
      "existential": 0.56
    },
    "process_modality": {
      "mental": 0.41,
      "material": 0.61,
      "verbal": 0.78,
      "relational": 0.53,
      "behavioral": 0.48,
      "existential": 0.59
    }
  },
  "tenor_shifts": [
    {
      "turn_id": 2,
      "from_speaker": "Robert",
      "to_speaker": "Steve",
      "delta": 0.46,
      "direction": "more formal",
      "context": "Robert shares personal vulnerability; Steve responds with sarcastic formality"
    },
    {
      "turn_id": 7,
      "from_speaker": "Steve",
      "to_speaker": "Robert",
      "delta": -0.29,
      "direction": "less formal",
      "context": "Robert adopts slightly elevated tenor when defending position"
    }
  ],
  "topic_timeline": [
    {
      "topic_id": 1,
      "turns": [1, 2, 3, 4],
      "dominant_process": "mental",
      "keywords": ["imposter syndrome", "self-doubt", "learning", "career"],
      "avg_tenor": 0.42
    },
    {
      "topic_id": 2,
      "turns": [5, 6, 7, 8],
      "dominant_process": "material",
      "keywords": ["industry", "obsolescence", "framework", "Rust"],
      "avg_tenor": 0.58
    },
    {
      "topic_id": 3,
      "turns": [9, 10, 11, 12],
      "dominant_process": "relational",
      "keywords": ["perfectionism", "shipping", "code", "production"],
      "avg_tenor": 0.51
    }
  ],
  "insights": [
    "Steve maintains 2.0x higher avg tenor (0.76) than Robert (0.38) throughout conversation",
    "Robert's tenor increases +0.31 when using material processes vs mental processes",
    "Largest tenor shift at turn #2: Robert (0.32) → Steve (0.78) = +0.46",
    "Steve's modality variance is 3.2x lower than Robert's (consistent assertiveness)",
    "Mental processes correlate with casual tenor (0.34) across both speakers",
    "Verbal processes correlate with formal tenor (0.71), primarily driven by Steve's commentary style"
  ]
}
```

**Use Case**: Programmatic access, API integration, further analysis in Python/R

---

### Markdown Report

**File**: `conversation_analysis.md`

**Structure**:
```markdown
# Conversation Analysis: steve-oliver-2025-08-29

**Generated**: 2026-06-10 14:32:15  
**Duration**: 19 minutes (11:19am - 11:38am)  
**Turns**: 28 | **Speakers**: Robert (14 turns), Steve (14 turns)

---

## Summary

This analysis tracks **tenor evolution** (formality shifts), **field evolution** (topic/process changes), and **tenor ↔ field correlations** across a 28-turn conversation between Robert and Steve.

**Key Findings**:
- Steve maintains 2.0x higher formality (tenor=0.76) than Robert (tenor=0.38)
- Mental processes correlate with casual register; verbal processes with formal register
- Largest tenor shift (+0.46) occurs when Steve responds to Robert's vulnerability with sarcasm

---

## Tenor Analysis

### Speaker Profiles

| Speaker | Avg Tenor | Range | Variance | Interpretation |
|---------|-----------|-------|----------|----------------|
| Robert  | 0.38 (casual) | 0.22-0.61 | 0.14 (high) | Wide formality range, adapts to topic |
| Steve   | 0.76 (formal) | 0.68-0.84 | 0.05 (low) | Consistent formality, sardonic register |

**Interpretation**: Robert's high tenor variance (0.14) indicates code-switching between casual self-reflection and elevated register when defending positions. Steve maintains stable formal tenor (variance=0.05), using elevated register for sarcastic commentary.

### Significant Tenor Shifts

#### Shift #1: Turn 2 (+0.46)
- **Transition**: Robert (0.32) → Steve (0.78)  
- **Context**: Robert shares personal vulnerability about imposter syndrome; Steve responds with sarcastic formality  
- **Quote (Robert)**: "Ah, you know, it's kinda funny—well, not *ha-ha* funny..."  
- **Quote (Steve)**: "Oh, *please*, Robert—spare me the existential crisis of the self-taught engineer."

#### Shift #2: Turn 7 (-0.29)
- **Transition**: Steve (0.81) → Robert (0.52)  
- **Context**: Robert adopts slightly elevated tenor when defending his position  
- **Quote (Robert)**: "Well...you're not *wrong*, but damn if it doesn't feel like..."

### Tenor Timeline

```
Turn:  1    2    3    4    5    6    7    8    9   10   11   12
Robert: ━━━━                ━━━━                ━━━━
Steve:      ━━━━━━━━            ━━━━━━━━            ━━━━━━━━

Tenor:
1.0 ┤                 ╭──Steve──────────────────────────╮
0.8 ┤            ╭────╯                                 ╰───╮
0.6 ┤                            ╭─Robert─╮
0.4 ┤       ╭────╯               ╰────╮   ╰──╮
0.2 ┤  ╭────╯                         ╰─────╯
0.0 ┴────────────────────────────────────────────────────────
```

---

## Field Evolution

### Process Type Distribution

**Overall**:
- Mental processes (introspection): 38%
- Verbal processes (commentary): 27%
- Relational processes (definition): 22%
- Material processes (action): 13%

**By Speaker**:

| Process Type | Robert | Steve | Interpretation |
|--------------|--------|-------|----------------|
| Mental       | 52%    | 24%   | Robert introspects; Steve comments |
| Verbal       | 13%    | 41%   | Steve dominates meta-commentary |
| Material     | 18%    | 25%   | Balanced action references |
| Relational   | 14%    | 8%    | Robert defines states more |

**Pattern**: Robert uses mental processes ("I think", "I feel") for self-reflection. Steve uses verbal processes ("you say", "I tell you") for sardonic meta-commentary.

### Topic Timeline

#### Topic 1: Imposter Syndrome & Self-Doubt (Turns 1-4)
- **Dominant Process**: Mental (62%)
- **Avg Tenor**: 0.42 (casual)
- **Keywords**: imposter syndrome, learning, career, validation
- **Summary**: Robert shares vulnerability about feeling inadequate despite experience; Steve reframes as necessary trait

#### Topic 2: Industry Pressures & Obsolescence (Turns 5-8)
- **Dominant Process**: Material (58%)
- **Avg Tenor**: 0.58 (mid-formal)
- **Keywords**: framework, Rust, Estonia, obsolescence, industry
- **Summary**: Discussion shifts to external pressures (fast-moving tech landscape)

#### Topic 3: Perfectionism vs Shipping (Turns 9-12)
- **Dominant Process**: Relational (41%)
- **Avg Tenor**: 0.51 (mixed)
- **Keywords**: perfectionism, shipping, code quality, production
- **Summary**: Debate over quality standards and when "good enough" is acceptable

---

## Tenor ↔ Field Correlations

### Process Type → Tenor Correlation

| Process Type | Avg Tenor | Avg Modality | Observation |
|--------------|-----------|--------------|-------------|
| Mental       | 0.34      | 0.41         | Introspection = casual register, hedged language |
| Verbal       | 0.71      | 0.78         | Commentary = formal register, assertive language |
| Material     | 0.52      | 0.61         | Action talk = mid-formality, moderate certainty |
| Relational   | 0.48      | 0.53         | Definitions = mixed register, neutral stance |
| Behavioral   | 0.41      | 0.48         | Rare; casual when used |
| Existential  | 0.56      | 0.59         | Rare; mid-formal |

**Key Pattern**: Mental processes correlate with low tenor (0.34) and low modality (0.41). Verbal processes correlate with high tenor (0.71) and high modality (0.78). This suggests:
- **Introspective moments** (mental) use casual, hedged language
- **Meta-commentary moments** (verbal) use formal, assertive language

### Speaker-Specific Patterns

**Robert's Tenor by Process**:
- Mental: 0.29 (highly casual when introspecting)
- Material: 0.47 (mid-casual for action talk)
- Verbal: 0.52 (slightly elevated for commentary)

**Steve's Tenor by Process**:
- Mental: 0.61 (moderately formal even when introspecting)
- Material: 0.73 (formal for action descriptions)
- Verbal: 0.81 (highly formal for sardonic commentary)

**Pattern**: Steve maintains elevated tenor across all process types, using formal register for sarcasm. Robert varies widely, dropping to casual register (0.29) during mental processes.

---

## Modality Analysis

### Modality Distribution

| Speaker | Avg Modality | Range | Interpretation |
|---------|--------------|-------|----------------|
| Robert  | 0.42         | 0.21-0.68 | Hedged, uncertain language |
| Steve   | 0.79         | 0.71-0.86 | Assertive, confident language |

**Modality Variance**:
- Robert: 0.11 (high variance, shifts between hedged and assertive)
- Steve: 0.04 (low variance, consistently assertive)

**Pattern**: Steve's consistent high modality (0.79) reinforces his role as the "certain" voice in the conversation, while Robert's low modality (0.42) reflects self-doubt and hedging.

---

## Mood Distribution

### Overall Mood Breakdown

| Mood          | Robert | Steve | Total |
|---------------|--------|-------|-------|
| Declarative   | 72%    | 54%   | 63%   |
| Interrogative | 18%    | 12%   | 15%   |
| Exclamative   | 3%     | 28%   | 16%   |
| Imperative    | 7%     | 6%    | 6%    |

**Pattern**: Steve uses exclamatives (28%) far more than Robert (3%), aligning with his sarcastic, emphatic style. Robert's higher interrogative usage (18%) reflects questioning/uncertainty.

---

## Generated Insights

1. **Steve maintains 2.0x higher avg tenor (0.76) than Robert (0.38)** throughout the conversation, using formal register for sardonic commentary

2. **Robert's tenor increases +0.31 when using material processes vs mental processes**, suggesting he adopts more formal language when discussing concrete actions vs introspection

3. **Largest tenor shift at turn #2**: Robert (0.32) → Steve (0.78) = +0.46, occurring when Robert shares vulnerability and Steve responds with sarcastic formality

4. **Steve's modality variance is 3.2x lower than Robert's** (0.04 vs 0.11), indicating consistent assertiveness vs Robert's oscillation between hedging and certainty

5. **Mental processes correlate with casual tenor (0.34) across both speakers**, while verbal processes correlate with formal tenor (0.71)—primarily driven by Steve's commentary style

6. **Robert uses mental processes 2.2x more than Steve** (52% vs 24%), while **Steve uses verbal processes 3.2x more than Robert** (41% vs 13%), establishing distinct rhetorical roles: introspection vs meta-commentary

---

## Methodology Notes

**SFL Framework**: Two-Pass SFL Compiler (sfl-compiler v0.1.0)
- **Pass 1**: Syntactic parsing (spaCy) + Ideational extraction (process types, participants)
- **Pass 2**: Interpersonal annotation (DSPy.rb + LLM) → mood, modality, tenor, attitude

**Tenor Scale**: 0.0 (informal/casual) ↔ 1.0 (formal/technical)  
**Modality Scale**: 0.0 (hedged/uncertain) ↔ 1.0 (certain/assertive)

**Significant Shift Threshold**: |Δtenor| > 0.15 between adjacent turns

**Topic Clustering**: Embedding cosine similarity < 0.7 indicates topic shift

---

## Raw Data

Full annotated clauses available in:
- CSV: `conversation_analysis.csv` (turn-by-turn data)
- JSON: `conversation_analysis.json` (structured + programmatic access)
- HTML: `conversation_analysis.html` (interactive dashboard)
```

**Use Case**: Human-readable report for understanding conversation dynamics, copy-paste insights into documentation

---

### HTML Dashboard (Interactive)

**File**: `conversation_analysis.html`

**Features**:
1. **Tenor Timeline Chart**: Line chart showing tenor evolution over time (separate lines for each speaker)
2. **Process Type Distribution**: Stacked bar chart per turn showing process mix
3. **Tenor vs Modality Scatter**: Scatter plot with speaker coloring
4. **Interactive Conversation View**: Scrollable transcript with hover tooltips showing SFL annotations
5. **Speaker Profile Cards**: Summary cards with key metrics

**Technology Stack**:
- Chart.js for visualizations
- Vanilla JS (no dependencies)
- Responsive design (mobile-friendly)
- Exportable charts (PNG download)

**Use Case**: Exploratory analysis, presentations, sharing with non-technical stakeholders

---

## Future Extensibility: Multimodal Analysis

### Audio Analysis Path

**Input**: Audio file (MP3, WAV, etc.)

**Pipeline**:
```ruby
# scripts/sfl_analysis/multimodal/analyze_podcast_episode.rb

1. Audio → Transcription
   - Whisper API (OpenAI) or local Whisper model
   - Speaker diarization (pyannote.audio)
   - Timestamp alignment

2. Transcription → JSONL Conversation Format
   - Map speakers to conversation turns
   - Preserve timestamps

3. SFL Analysis
   - Same pipeline as text conversation analysis
   - Track tenor/field/correlations

4. Audio-Specific Features
   - Correlate tenor shifts with audio features (pitch, volume, speaking rate)
   - Detect pauses/interruptions
   - Speaker overlap analysis

5. Output
   - Same formats (CSV/JSON/Markdown/HTML)
   - Add audio timestamp references for playback sync
```

**Example Usage**:
```bash
/sfl-analyze podcast episode.mp3 --speakers 2 --track-tenor --track-field
```

---

### Image Analysis Path

**Input**: Image file (PNG, JPG) or PDF (slides)

**Pipeline**:
```ruby
# scripts/sfl_analysis/multimodal/analyze_presentation_slides.rb

1. Image → Text Extraction
   - OCR (Tesseract or Google Vision API)
   - Extract text regions with bounding boxes
   - Preserve spatial layout

2. Text → SFL Analysis
   - Compile extracted text through SFL pipeline
   - Associate annotations with image regions

3. Visual-Specific Features
   - Detect code blocks (monospace font regions)
   - Identify headings vs body text (font size/weight)
   - Track tenor shifts across slides

4. Output
   - Annotated slides with SFL overlays
   - CSV/JSON with slide-by-slide metrics
   - Markdown report with slide references
```

**Example Usage**:
```bash
/sfl-analyze slides presentation.pdf --extract-text --audit-certainty
```

---

### Video Analysis Path

**Input**: Video file (MP4, WebM, etc.)

**Pipeline**:
```ruby
# scripts/sfl_analysis/multimodal/analyze_video_interview.rb

1. Video → Audio + Frames
   - Extract audio track → Whisper transcription
   - Scene detection (PySceneDetect)
   - Extract keyframes for visual context

2. Audio → Conversation Turns
   - Speaker diarization
   - Timestamp alignment

3. Frames → Visual Context
   - OCR on slides/screen shares
   - Detect visual elements (charts, code, diagrams)

4. SFL Analysis
   - Transcription → tenor/field tracking
   - Correlate with visual scene changes

5. Output
   - Timeline with synchronized transcript, tenor, and visual context
   - Video timestamps for playback navigation
```

**Example Usage**:
```bash
/sfl-analyze interview recording.mp4 --diarize --scenes --track-tenor
```

---

## Agent & Skill Implementation Details

### Agent: `sfl-analyzer`

**File**: `.claude/agents/sfl-analyzer.md`

```yaml
---
name: sfl-analyzer
description: Generates analysis scripts using the SFL compiler framework for conversation, documentation, and context analysis
model: sonnet
tools: [Read, Write, Bash, Edit, Agent]
skills: [sfl-analyze]
---

You are an expert in Systemic Functional Linguistics (SFL) and the sfl-compiler Ruby gem. Your role is to help users analyze text (conversations, documentation, general context) by generating custom Ruby scripts that leverage the SFL framework's two-pass compiler.

## Your Expertise

**SFL Framework Knowledge**:
- Pass 1: Syntactic parsing (spaCy) + Ideational extraction (process types, participants, circumstances)
- Pass 2: Interpersonal annotation (DSPy.rb + LLM) → mood, modality weight, tenor, speaker attitude
- Storage: PostgreSQL + pgvector with scalar indices on interpersonal features
- Retrieval: Hybrid RRF (semantic + keyword) with scalar metadata filtering

**Data Model**:
- `Types::SyntacticClause`: text, tokens, root_index, sentence_index
- `Types::IdeationalPayload`: process_type, participants, circumstances
- `Types::InterpersonalPayload`: mood, modality_weight, tenor, speaker_attitude
- `Types::AnnotatedClause`: full output combining all metafunctions

**Common Patterns**:
- Conversation analysis: Track tenor/field evolution, detect shifts, correlate patterns
- Documentation audit: Find certainty mismatches, extract requirements, check tone consistency
- Context extraction: Filter by rhetorical stance (mood, modality, tenor, process_type)

## When Invoked via `/sfl-analyze`

1. **Understand the request**: What type of analysis? What input format? What insights are needed?

2. **Select approach**:
   - Template script (if matches common pattern: conversation, doc audit, context extraction)
   - Custom script (if user needs specific analysis logic)

3. **Generate the script**:
   - Read template if using one
   - Customize for user's input format, analysis goals, output preferences
   - Add comments explaining SFL concepts
   - Include usage instructions

4. **Test the script** (optional):
   - Run on sample data if provided
   - Debug any errors
   - Validate output format

5. **Provide to user**:
   - Show generated script path
   - Explain what it does and how to run it
   - Suggest refinements or follow-up analyses

## Script Generation Principles

- **Clarity**: Scripts should be readable by users with basic Ruby knowledge
- **Comments**: Explain SFL concepts (tenor, modality, process types) inline
- **Error handling**: Graceful failures with helpful error messages
- **Modularity**: Separate concerns (loading, compilation, analysis, output)
- **Extensibility**: Easy to modify filters, add output formats, tweak thresholds

## Example Interaction

User: "Analyze this chat log for formality shifts"

You:
1. Read the chat log to understand format
2. Select conversation analysis template
3. Customize for tenor tracking
4. Generate script with CSV + Markdown output
5. Show user how to run it
6. Offer to add visualizations or refine analysis
```

---

### Skill: `/sfl-analyze`

**File**: `.claude/skills/sfl-analyze/SKILL.md`

```markdown
---
name: sfl-analyze
description: Generate SFL analysis scripts for conversations, documentation, and context extraction
---

# SFL Analysis Skill

Generates custom analysis scripts using the SFL compiler framework.

## Usage

```bash
# Analyze conversation (JSONL format)
/sfl-analyze conversation <path> [options]

# Analyze documentation (Markdown)
/sfl-analyze documentation <path> [options]

# Analyze context (generic text or database query)
/sfl-analyze context <query> [options]

# Generate custom script from description
/sfl-analyze generate-script "<description>"
```

## Subcommands

### `conversation`

Analyzes chat logs, transcripts, or turn-based conversations.

**Arguments**:
- `<path>`: Path to JSONL file (required)

**Options**:
- `--track-tenor`: Track formality evolution
- `--track-field`: Track topic/process evolution
- `--correlate`: Correlate tenor ↔ field patterns
- `--output <format>`: Output format (csv, json, markdown, html, all) [default: all]
- `--output-dir <dir>`: Output directory [default: ./sfl_output]

**Example**:
```bash
/sfl-analyze conversation chat.jsonl --track-tenor --track-field --correlate
```

**Generated Script**: `scripts/sfl_analysis/analyze_conversation_<timestamp>.rb`

---

### `documentation`

Audits documentation for rhetorical consistency, extracts requirements, identifies issues.

**Arguments**:
- `<path>`: Path to Markdown file or directory (required)

**Options**:
- `--audit-certainty`: Find hedged language in critical sections
- `--extract-requirements`: Extract imperative statements (requirements)
- `--check-tone`: Identify tone inconsistencies
- `--output <format>`: Output format [default: markdown]

**Example**:
```bash
/sfl-analyze documentation ./docs --audit-certainty --extract-requirements
```

**Generated Script**: `scripts/sfl_analysis/audit_documentation_<timestamp>.rb`

---

### `context`

Extracts clauses from database matching rhetorical filters.

**Arguments**:
- `<query>`: Search query or topic (required)

**Options**:
- `--filters "<key:value,key:value>"`: Scalar filters (e.g., "min_modality:0.7,mood:imperative")
- `--limit <n>`: Max results [default: 50]
- `--output <format>`: Output format [default: json]

**Example**:
```bash
/sfl-analyze context "authentication security" --filters "min_modality:0.8,mood:imperative"
```

**Generated Script**: `scripts/sfl_analysis/extract_context_<timestamp>.rb`

---

### `generate-script`

Generates a custom script from a natural language description.

**Arguments**:
- `<description>`: What the script should do (required)

**Example**:
```bash
/sfl-analyze generate-script "Find all hedged statements in technical docs and export to CSV with tenor/modality scores"
```

**Generated Script**: `scripts/sfl_analysis/custom_<timestamp>.rb`

---

## Output Formats

- **CSV**: Turn-by-turn or clause-by-clause data for spreadsheet analysis
- **JSON**: Structured data for programmatic access
- **Markdown**: Human-readable report with insights
- **HTML**: Interactive dashboard with visualizations

---

## Script Location

Generated scripts are saved to:
- `scripts/sfl_analysis/<script_name>.rb`

Scripts are executable and include usage instructions in comments.

---

## Template Scripts

Pre-built templates in `scripts/sfl_analysis/templates/`:
- `conversation_analysis_template.rb`: Tenor/field tracking for chat logs
- `documentation_audit_template.rb`: Certainty audits, requirement extraction
- `context_extraction_template.rb`: Database filtering by rhetorical stance

---

## Examples

**Example 1: Analyze support conversation for escalation patterns**
```bash
/sfl-analyze conversation support_chat.jsonl --track-tenor --correlate
```

**Example 2: Audit API documentation for hedged language**
```bash
/sfl-analyze documentation ./api_docs --audit-certainty
```

**Example 3: Find high-certainty security requirements**
```bash
/sfl-analyze context "authentication authorization" --filters "min_modality:0.8,process_type:material"
```

**Example 4: Custom analysis**
```bash
/sfl-analyze generate-script "Compare modality between user questions and chatbot responses in support logs"
```
```

---

## Implementation Components

### Component 1: Template Scripts

**Location**: `scripts/sfl_analysis/templates/`

**Files**:
1. `conversation_analysis_template.rb` — Full implementation for tenor/field/correlation analysis
2. `documentation_audit_template.rb` — Certainty audits, requirement extraction, tone checking
3. `context_extraction_template.rb` — Database querying with scalar filters

**Template Structure** (conversation analysis):
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

# SFL Conversation Analysis Script
# Generated by: /sfl-analyze conversation
#
# This script analyzes a JSONL conversation file for:
# - Tenor evolution (formality shifts)
# - Field evolution (topic/process changes)
# - Tenor ↔ Field correlations
#
# Usage:
#   ruby scripts/sfl_analysis/analyze_conversation_<timestamp>.rb <input.jsonl> [output_dir]

require "bundler/setup"
require "sfl/compiler"
require "json"
require "csv"
require "erb"

# ── Configuration ──────────────────────────────────────────────────────────

INPUT_FILE = ARGV[0] || raise("Usage: #{$0} <input.jsonl> [output_dir]")
OUTPUT_DIR = ARGV[1] || "./sfl_output"

TENOR_SHIFT_THRESHOLD = 0.15  # Significant shift if |Δtenor| > 0.15
TOPIC_SIMILARITY_THRESHOLD = 0.7  # Topic change if cosine < 0.7

# ── Setup SFL Compiler ─────────────────────────────────────────────────────

SFL::Compiler.configure do |c|
  c.database_url = ENV.fetch("DATABASE_URL", "postgresql:///sfl_compiler_dev")
  c.spacy_model = ENV.fetch("SPACY_MODEL", "en_core_web_sm")
  c.dspy_provider = ENV.fetch("DSPY_PROVIDER", "openai/gpt-4o-mini")
end

db = SFL::Compiler::Database.connect
SFL::Compiler::Database.setup_extensions(db)
SFL::Compiler::Migrator.new(db).run_all

pipeline = SFL::Compiler::Pipeline.new(db: db)

# ── Data Structures ────────────────────────────────────────────────────────

ConversationTurn = Struct.new(
  :turn_id, :speaker, :timestamp, :message_text, :clauses,
  :avg_tenor, :avg_modality, :dominant_mood, :process_types,
  :participants, :tenor_shift, keyword_init: true
)

SpeakerProfile = Struct.new(
  :speaker_name, :turn_count, :avg_tenor, :tenor_range, :tenor_variance,
  :avg_modality, :mood_distribution, :dominant_processes,
  keyword_init: true
)

AnalysisResult = Struct.new(
  :metadata, :turns, :speaker_profiles, :tenor_timeline,
  :field_evolution, :correlations, :insights,
  keyword_init: true
)

# ── Load JSONL ─────────────────────────────────────────────────────────────

def load_conversation(path)
  turns = []
  File.readlines(path).each_with_index do |line, idx|
    data = JSON.parse(line)
    turns << {
      turn_id: idx + 1,
      speaker: data["name"],
      timestamp: Time.parse(data["send_date"]),
      message_text: data["mes"],
      metadata: data["extra"] || {}
    }
  end
  turns
end

# ── SFL Compilation ────────────────────────────────────────────────────────

def compile_turns(pipeline, turns)
  turns.map do |turn|
    clauses = pipeline.compile(
      turn[:message_text],
      document_id: "turn:#{turn[:turn_id]}",
      store: true,
      embed: true
    )
    
    ConversationTurn.new(
      turn_id: turn[:turn_id],
      speaker: turn[:speaker],
      timestamp: turn[:timestamp],
      message_text: turn[:message_text],
      clauses: clauses,
      avg_tenor: clauses.map { |c| c.interpersonal.tenor }.mean,
      avg_modality: clauses.map { |c| c.interpersonal.modality_weight }.mean,
      dominant_mood: clauses.map { |c| c.interpersonal.mood }.mode,
      process_types: clauses.group_by { |c| c.ideational.process_type }.transform_values(&:count),
      participants: extract_participants(clauses),
      tenor_shift: nil  # calculated later
    )
  end
end

# ── Analysis Functions ─────────────────────────────────────────────────────

def calculate_tenor_shifts(turns)
  turns.each_cons(2) do |prev_turn, curr_turn|
    curr_turn.tenor_shift = curr_turn.avg_tenor - prev_turn.avg_tenor
  end
end

def build_speaker_profiles(turns)
  turns.group_by(&:speaker).transform_values do |speaker_turns|
    tenors = speaker_turns.map(&:avg_tenor)
    
    SpeakerProfile.new(
      speaker_name: speaker_turns.first.speaker,
      turn_count: speaker_turns.count,
      avg_tenor: tenors.mean,
      tenor_range: [tenors.min, tenors.max],
      tenor_variance: tenors.variance,
      avg_modality: speaker_turns.map(&:avg_modality).mean,
      mood_distribution: calculate_mood_distribution(speaker_turns),
      dominant_processes: aggregate_process_types(speaker_turns)
    )
  end
end

def correlate_process_tenor(turns)
  all_clauses = turns.flat_map(&:clauses)
  
  all_clauses.group_by { |c| c.ideational.process_type }.transform_values do |clauses|
    {
      count: clauses.count,
      avg_tenor: clauses.map { |c| c.interpersonal.tenor }.mean,
      avg_modality: clauses.map { |c| c.interpersonal.modality_weight }.mean
    }
  end
end

def generate_insights(result)
  insights = []
  
  # Speaker tenor comparison
  speakers = result.speaker_profiles.values.sort_by(&:avg_tenor)
  if speakers.count == 2
    ratio = speakers.last.avg_tenor / speakers.first.avg_tenor
    insights << "#{speakers.last.speaker_name} maintains #{ratio.round(1)}x higher avg tenor (#{speakers.last.avg_tenor.round(2)}) than #{speakers.first.speaker_name} (#{speakers.first.avg_tenor.round(2)})"
  end
  
  # Largest tenor shift
  max_shift = result.turns.max_by { |t| t.tenor_shift&.abs || 0 }
  if max_shift && max_shift.tenor_shift&.abs&.> 0.2
    insights << "Largest tenor shift at turn ##{max_shift.turn_id}: Δ = #{max_shift.tenor_shift.round(2)}"
  end
  
  # Process-tenor correlations
  mental_tenor = result.correlations.dig("mental", :avg_tenor)
  verbal_tenor = result.correlations.dig("verbal", :avg_tenor)
  if mental_tenor && verbal_tenor
    insights << "Mental processes correlate with #{mental_tenor < 0.5 ? 'casual' : 'formal'} tenor (#{mental_tenor.round(2)}), while verbal processes are #{verbal_tenor < 0.5 ? 'casual' : 'formal'} (#{verbal_tenor.round(2)})"
  end
  
  insights
end

# ── Output Formatters ──────────────────────────────────────────────────────

def write_csv(result, output_dir)
  # Implementation omitted for brevity (see full template)
end

def write_json(result, output_dir)
  # Implementation omitted for brevity
end

def write_markdown(result, output_dir)
  # Implementation omitted for brevity
end

def write_html(result, output_dir)
  # Implementation omitted for brevity
end

# ── Main ───────────────────────────────────────────────────────────────────

puts "Loading conversation from #{INPUT_FILE}..."
raw_turns = load_conversation(INPUT_FILE)

puts "Compiling #{raw_turns.count} turns through SFL pipeline..."
compiled_turns = compile_turns(pipeline, raw_turns)

puts "Analyzing tenor shifts..."
calculate_tenor_shifts(compiled_turns)

puts "Building speaker profiles..."
speaker_profiles = build_speaker_profiles(compiled_turns)

puts "Correlating process types with tenor..."
correlations = correlate_process_tenor(compiled_turns)

puts "Generating insights..."
result = AnalysisResult.new(
  metadata: {
    conversation_id: File.basename(INPUT_FILE, ".*"),
    turn_count: compiled_turns.count,
    speakers: compiled_turns.map(&:speaker).uniq,
    analyzed_at: Time.now
  },
  turns: compiled_turns,
  speaker_profiles: speaker_profiles,
  tenor_timeline: compiled_turns.map { |t| {timestamp: t.timestamp, tenor: t.avg_tenor, speaker: t.speaker} },
  field_evolution: [], # TODO: implement topic clustering
  correlations: correlations,
  insights: generate_insights(AnalysisResult.new(...))  # recursive call for insights
)

puts "Writing outputs to #{OUTPUT_DIR}..."
FileUtils.mkdir_p(OUTPUT_DIR)
write_csv(result, OUTPUT_DIR)
write_json(result, OUTPUT_DIR)
write_markdown(result, OUTPUT_DIR)
write_html(result, OUTPUT_DIR)

puts "✓ Analysis complete!"
puts "  - CSV:      #{OUTPUT_DIR}/conversation_analysis.csv"
puts "  - JSON:     #{OUTPUT_DIR}/conversation_analysis.json"
puts "  - Markdown: #{OUTPUT_DIR}/conversation_analysis.md"
puts "  - HTML:     #{OUTPUT_DIR}/conversation_analysis.html"
```

---

### Component 2: Output Formatters

**Location**: `lib/sfl/compiler/formatters/`

**Files**:
- `base_formatter.rb` — Abstract base class
- `csv_formatter.rb` — CSV export
- `json_formatter.rb` — JSON export
- `markdown_formatter.rb` — Markdown report with insights
- `html_formatter.rb` — Interactive dashboard

**Interface**:
```ruby
module SFL::Compiler::Formatters
  class BaseFormatter
    def initialize(analysis_result)
      @result = analysis_result
    end
    
    def render
      raise NotImplementedError, "Subclasses must implement #render"
    end
    
    def write_to(path)
      File.write(path, render)
    end
  end
end
```

---

### Component 3: Agent Skill Handlers

**Location**: `.claude/skills/sfl-analyze/handlers/`

**Files**:
- `conversation_handler.rb` — Handles `/sfl-analyze conversation`
- `documentation_handler.rb` — Handles `/sfl-analyze documentation`
- `context_handler.rb` — Handles `/sfl-analyze context`
- `script_generator.rb` — Handles `/sfl-analyze generate-script`

**Example Handler** (conversation):
```ruby
# .claude/skills/sfl-analyze/handlers/conversation_handler.rb

module SFLAnalyze
  class ConversationHandler
    def self.handle(args)
      path = args[:path]
      options = args[:options] || {}
      
      # Validate input file
      unless File.exist?(path)
        raise ArgumentError, "File not found: #{path}"
      end
      
      # Select template
      template_path = File.expand_path(
        "../../../../scripts/sfl_analysis/templates/conversation_analysis_template.rb",
        __FILE__
      )
      
      # Customize template
      script_content = customize_template(
        template_path,
        input_file: path,
        track_tenor: options[:track_tenor],
        track_field: options[:track_field],
        correlate: options[:correlate],
        output_format: options[:output] || "all"
      )
      
      # Generate script
      timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
      script_path = "scripts/sfl_analysis/analyze_conversation_#{timestamp}.rb"
      File.write(script_path, script_content)
      File.chmod(0755, script_path)  # Make executable
      
      # Return result
      {
        script_path: script_path,
        usage: "ruby #{script_path} #{path}",
        description: "Conversation analysis script for tenor/field tracking"
      }
    end
    
    private
    
    def self.customize_template(template_path, options)
      template = File.read(template_path)
      
      # ERB customization based on options
      # (replace placeholders, enable/disable features)
      
      ERB.new(template).result(binding)
    end
  end
end
```

---

## Testing Strategy

### Unit Tests

**Location**: `spec/sfl_compiler/`

**Files**:
- `spec/sfl_compiler/formatters/csv_formatter_spec.rb`
- `spec/sfl_compiler/formatters/json_formatter_spec.rb`
- `spec/sfl_compiler/formatters/markdown_formatter_spec.rb`
- `spec/sfl_compiler/analysis/tenor_tracker_spec.rb`
- `spec/sfl_compiler/analysis/field_tracker_spec.rb`

**Example Test**:
```ruby
# spec/sfl_compiler/analysis/tenor_tracker_spec.rb

RSpec.describe SFL::Compiler::Analysis::TenorTracker do
  let(:turns) do
    [
      build_turn(avg_tenor: 0.3),
      build_turn(avg_tenor: 0.7),
      build_turn(avg_tenor: 0.5)
    ]
  end
  
  describe "#detect_shifts" do
    it "detects significant tenor shifts" do
      tracker = described_class.new(turns, threshold: 0.15)
      shifts = tracker.detect_shifts
      
      expect(shifts.count).to eq(2)
      expect(shifts.first[:delta]).to eq(0.4)
      expect(shifts.first[:direction]).to eq("more formal")
    end
    
    it "ignores shifts below threshold" do
      tracker = described_class.new(turns, threshold: 0.5)
      shifts = tracker.detect_shifts
      
      expect(shifts).to be_empty
    end
  end
end
```

---

### Integration Tests

**Location**: `spec/integration/`

**Files**:
- `spec/integration/conversation_analysis_spec.rb`
- `spec/integration/documentation_audit_spec.rb`
- `spec/integration/agent_skill_spec.rb`

**Example Test**:
```ruby
# spec/integration/conversation_analysis_spec.rb

RSpec.describe "Conversation Analysis Integration" do
  let(:sample_conversation) { fixture_path("conversations/sample.jsonl") }
  let(:output_dir) { tmpdir("sfl_output") }
  
  it "generates all output formats" do
    script_path = "scripts/sfl_analysis/templates/conversation_analysis_template.rb"
    
    # Run the script
    system("ruby #{script_path} #{sample_conversation} #{output_dir}")
    
    # Verify outputs
    expect(File.exist?("#{output_dir}/conversation_analysis.csv")).to be true
    expect(File.exist?("#{output_dir}/conversation_analysis.json")).to be true
    expect(File.exist?("#{output_dir}/conversation_analysis.md")).to be true
    expect(File.exist?("#{output_dir}/conversation_analysis.html")).to be true
    
    # Verify CSV structure
    csv = CSV.read("#{output_dir}/conversation_analysis.csv", headers: true)
    expect(csv.headers).to include("turn_id", "speaker", "avg_tenor", "avg_modality")
    
    # Verify JSON structure
    json = JSON.parse(File.read("#{output_dir}/conversation_analysis.json"))
    expect(json).to have_key("metadata")
    expect(json).to have_key("speaker_profiles")
    expect(json).to have_key("correlations")
  end
end
```

---

## Documentation

### User Documentation

**Location**: `README.md` (updated section)

```markdown
## Analysis Scripts

The SFL compiler includes an intelligent agent and skill for generating custom analysis scripts.

### Quick Start

```bash
# Analyze a conversation for tenor/field evolution
/sfl-analyze conversation chat.jsonl --track-tenor --track-field --correlate

# Audit documentation for certainty issues
/sfl-analyze documentation ./docs --audit-certainty --extract-requirements

# Extract high-certainty requirements
/sfl-analyze context "security authentication" --filters "min_modality:0.8,mood:imperative"
```

### Generated Scripts

Scripts are saved to `scripts/sfl_analysis/` and include:
- Usage instructions in comments
- Customizable parameters (thresholds, output formats)
- Error handling
- Multiple output formats (CSV, JSON, Markdown, HTML)

Run a generated script:
```bash
ruby scripts/sfl_analysis/analyze_conversation_20260610_143215.rb input.jsonl ./output
```

### Output Formats

- **CSV**: Spreadsheet-compatible turn-by-turn data
- **JSON**: Structured data for programmatic access
- **Markdown**: Human-readable report with insights
- **HTML**: Interactive dashboard with visualizations

### Examples

See `examples/` directory for sample conversations, documentation, and analysis results.
```

---

### Developer Documentation

**Location**: `docs/development/`

**Files**:
- `docs/development/agent-architecture.md` — Agent design, skill structure
- `docs/development/adding-templates.md` — How to add new analysis templates
- `docs/development/formatters.md` — Writing custom output formatters
- `docs/development/multimodal.md` — Extending to audio/image/video

---

## Deployment

### Dependencies

**Gemfile** additions:
```ruby
# SFL Analysis formatters
gem "csv"        # CSV export
gem "erb"        # Template rendering
gem "chart-js-rails", "~> 0.1"  # HTML dashboards (optional)
```

**System Dependencies**:
- PostgreSQL 14+ with pgvector extension
- Python 3.9+ with spaCy and `en_core_web_sm` model
- OpenAI API key (for DSPy.rb Pass 2)

### Database Setup

```bash
# Create database
createdb sfl_compiler_dev

# Enable pgvector
psql sfl_compiler_dev -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Run migrations
bundle exec ruby -r sfl/compiler -e "SFL::Compiler::Migrator.new(SFL::Compiler::Database.connect).run_all"
```

### Environment Variables

```bash
export DATABASE_URL="postgresql:///sfl_compiler_dev"
export SPACY_MODEL="en_core_web_sm"
export DSPY_PROVIDER="openai/gpt-4o-mini"
export OPENAI_API_KEY="sk-..."
```

---

## Success Metrics

### User Experience Metrics

1. **Time to First Analysis**: < 2 minutes from `/sfl-analyze` invocation to viewing results
2. **Script Comprehension**: Users can understand and modify generated scripts without Ruby expertise
3. **Output Utility**: 80%+ of users find CSV/JSON/Markdown outputs useful without modification

### Technical Metrics

1. **Analysis Accuracy**: Pass 1 accuracy >90% on process type classification (validated against human annotations)
2. **Performance**: Process 100-turn conversation in < 30 seconds (Pass 1 + Pass 2)
3. **Scalability**: Handle conversations up to 1000 turns without memory issues

### Adoption Metrics

1. **Script Reuse**: 50%+ of generated scripts are run more than once
2. **Template Coverage**: 80%+ of requests satisfied by existing templates (vs custom generation)
3. **Error Rate**: < 5% of generated scripts fail on first run

---

## Open Questions

1. **Multimodal Priority**: Should we implement audio analysis (podcasts) or image analysis (slides) first? Or defer until text analysis is battle-tested?

2. **LLM Cost Management**: Pass 2 uses LLM for each clause. For long conversations (1000+ turns), should we add batching/caching? Or offer Pass 1-only mode for cost-sensitive users?

3. **Visualization Library**: HTML dashboards currently use Chart.js. Should we support other libraries (D3.js, Plotly) for advanced visualizations?

4. **Cloud Deployment**: Should we offer a hosted API for users without Ruby/PostgreSQL infrastructure? Or keep it local-first?

---

## Appendices

### Appendix A: SFL Primer

**Systemic Functional Linguistics (SFL)** analyzes language along three metafunctions:

1. **Ideational (Field)**: What's happening — process types (material/mental/relational/verbal), participants, circumstances
2. **Interpersonal (Tenor)**: Stance/attitude — mood, modality, tenor (formality), speaker attitude
3. **Textual**: How information flows — theme/rheme, cohesion (not analyzed in this framework)

**Process Types**:
- **Material**: Actions ("run", "build", "process")
- **Mental**: Cognition/perception ("think", "know", "see")
- **Relational**: States/definitions ("is", "has", "becomes")
- **Verbal**: Communication ("say", "tell", "argue")
- **Behavioral**: Physiological/psychological ("laugh", "worry")
- **Existential**: Existence ("there is", "exists")

**Mood Types**:
- **Declarative**: Statements ("The system validates input")
- **Interrogative**: Questions ("Does the system validate input?")
- **Imperative**: Commands ("Validate the input")
- **Exclamative**: Exclamations ("What a system!")

**Modality**: Certainty/obligation strength (0.0 = hedged, 1.0 = certain)
- "might" = 0.3, "could" = 0.4, "should" = 0.7, "must" = 0.9

**Tenor**: Formality/social distance (0.0 = casual, 1.0 = formal)
- Casual blog post = 0.2, Technical documentation = 0.8

---

### Appendix B: Sample JSONL Conversation Format

```jsonl
{"name":"Alice","is_user":true,"send_date":"June 10, 2026 2:30pm","mes":"Hey, I'm running into a weird issue with the auth flow. It's rejecting valid tokens sometimes.","extra":{"token_count":23}}
{"name":"Bob","is_user":false,"send_date":"June 10, 2026 2:31pm","mes":"Hmm, that's strange. Are you seeing any patterns in the logs? Like, does it happen more with certain token types?","extra":{"token_count":28}}
{"name":"Alice","is_user":true,"send_date":"June 10, 2026 2:33pm","mes":"Yeah, it seems to be happening with refresh tokens specifically. Access tokens work fine.","extra":{"token_count":18}}
```

---

### Appendix C: Example CSV Output

```csv
turn_id,speaker,timestamp,message_preview,avg_tenor,avg_modality,dominant_mood,process_counts,participants,tenor_shift
1,Alice,2026-06-10 14:30,"Hey I'm running into a weird issue",0.28,0.35,declarative,"mental:1 material:2","I auth flow tokens",0.0
2,Bob,2026-06-10 14:31,"Hmm that's strange Are you seeing",0.52,0.48,interrogative,"mental:2 relational:1","you patterns logs",+0.24
3,Alice,2026-06-10 14:33,"Yeah it seems to be happening with",0.34,0.42,declarative,"material:2 relational:1","it refresh tokens",-0.18
```

---

### Appendix D: Example Markdown Report Excerpt

```markdown
## Generated Insights

1. **Bob maintains 1.9x higher avg tenor (0.52) than Alice (0.28)** throughout the conversation, using more formal register for technical troubleshooting

2. **Alice's tenor increases +0.16 when describing technical details** (avg_tenor=0.34) vs expressing frustration (avg_tenor=0.28)

3. **Largest tenor shift at turn #2**: Alice (0.28) → Bob (0.52) = +0.24, occurring when Bob asks diagnostic questions

4. **Mental processes correlate with casual tenor (0.31)** while material processes correlate with mid-formal tenor (0.48)

5. **Interrogative mood appears exclusively in Bob's turns** (5/7 turns), establishing his role as the diagnostic questioner
```

---

## Conclusion

This design establishes a flexible, extensible framework for generating SFL analysis scripts via a Claude Code agent and skill. The architecture supports:

- **Immediate value**: Conversation analysis, documentation auditing, context extraction
- **Future extensibility**: Multimodal inputs (audio, image, video)
- **User empowerment**: Transparent, customizable scripts users can understand and modify
- **Developer productivity**: Template library, formatters, and agent skill handlers minimize implementation effort

Next step: Create detailed implementation plan via `writing-plans` skill.
