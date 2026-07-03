# CohesionAnalyzer

**Location:** `lib/sfl/compiler/analysis/cohesion_analyzer.rb`
**Confidence:** EXTRACTED

---

## Transformation Contract

```
Array<ConversationTurn> → [CohesionAnalyzer.analyze] → Array<ConversationTurn> (with cohesion metrics)
```

| Input | Output | Condition |
|-------|--------|-----------|
| `Array<ConversationTurn>` | Same array with `cohesion` filled | turns non-empty |
| Empty array | `[]` | no-op |

---

## Responsibilities

- Calculate lexical repetition score
- Calculate conjunction density
- Calculate pronoun density
- Attach `CohesionMetrics` to each turn

---

## Key Components

| Component | Role |
|-----------|------|
| `analyze(turns)` | Main entry: add cohesion metrics to each turn |
| `calculate_metrics(clauses)` | Compute all three metrics from clauses |
| `calculate_repetition(tokens)` | 1.0 - (unique_content / total_content) |
| `calculate_density(tokens, pos_pattern)` | Count matching POS / total tokens |

---

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `Types::ConversationTurn` | Input/output struct |
| `Types::CohesionMetrics` | Output struct |

---

## Interactions

```mermaid
graph LR
    A[ConversationTurn[]] --> B[CohesionAnalyzer]
    B --> C[calculate_metrics]
    C --> D[repetition_score]
    C --> E[conjunction_density]
    C --> F[pronoun_density]
    D --> G[CohesionMetrics]
    E --> G
    F --> G
    G --> H[ConversationTurn with cohesion]
```

---

## User/Developer Experience

**Developer** calls `CohesionAnalyzer.new.analyze(turns)` and receives turns with `cohesion` attribute set to `CohesionMetrics`.

**User** sees cohesion scores in analysis results and markdown reports.

---

## Known Limitations

1. **POS pattern matching** — uses regex on POS tags, not full syntactic analysis
2. **No cross-turn cohesion** — metrics are per-turn only

---

## Design Rationale

Three metrics capture different aspects of text cohesion:
- **Repetition**: lexical density (how much vocabulary is reused)
- **Conjunction**: logical connectivity (how clauses are linked)
- **Pronoun**: referential cohesion (how entities are tracked)

---

## Ruby Pragmatist Insight

> CohesionAnalyzer is a **textual physicist** — it measures the forces that hold a text together. Repetition is friction (words grinding against each other), conjunction is the mortar between bricks, pronouns are the threads that tie distant sentences to their antecedents.

---

## Trace Path

```
conversation_analyzer.rb:119  build_result
  └─► cohesion_analyzer.rb:11  analyze
       ├─► cohesion_analyzer.rb:20  calculate_metrics
       ├─► cohesion_analyzer.rb:34  calculate_repetition
       └─► cohesion_analyzer.rb:42  calculate_density
```
