# CorrelationAnalyzer

**Location:** `lib/sfl/compiler/analysis/correlation_analyzer.rb`
**Confidence:** EXTRACTED

---

## Transformation Contract

```
Array<ConversationTurn> → [CorrelationAnalyzer.correlate_process_tenor] → Hash
```

| Input | Output | Condition |
|-------|--------|-----------|
| `Array<ConversationTurn>` | `Hash` with correlation coefficients | turns non-empty |
| Empty hash | `{}` | no-op |

---

## Responsibilities

- Calculate correlation between process types and tenor scores
- Calculate correlation between process types and modality scores
- Return correlation coefficients (Pearson r)

---

## Key Components

| Component | Role |
|-----------|------|
| `initialize(turns)` | Store turns array |
| `correlate_process_tenor` | Main entry: calculate correlations |

---

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `Types::ConversationTurn` | Input struct |

---

## Interactions

```mermaid
graph LR
    A[ConversationTurn[]] --> B[CorrelationAnalyzer]
    B --> C[Extract Process Types]
    B --> D[Extract Tenor/Modality]
    C --> E[Pearson Correlation]
    D --> E
    E --> F[Hash with r values]
```

---

## User/Developer Experience

**Developer** calls `CorrelationAnalyzer.new(turns).correlate_process_tenor` and receives a hash:
- `modality_tenor_correlation` — Pearson r between modality and tenor
- `process_tenor_correlations` — per-process-type correlations

**User** sees correlation insights in analysis results and markdown reports.

---

## Known Limitations

1. **Pearson only** — no Spearman or other correlation measures
2. **Process type encoding** — process types are encoded as integers for correlation

---

## Design Rationale

Correlation analysis reveals whether certain process types (material, mental, verbal, etc.) tend to co-occur with specific tenor or modality levels, providing insights into how language structure relates to interpersonal features.

---

## Ruby Pragmatist Insight

> CorrelationAnalyzer is a **detective** — it looks for patterns that suggest relationships between seemingly independent variables. When material processes correlate with high tenor, it suggests formal, action-oriented language. When mental processes correlate with low modality, it suggests uncertainty about internal states.

---

## Trace Path

```
conversation_analyzer.rb:119  build_result
  └─► correlation_analyzer.rb:18  correlate_process_tenor
```
