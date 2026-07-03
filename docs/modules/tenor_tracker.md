# TenorTracker

**Location:** `lib/sfl/compiler/analysis/tenor_tracker.rb`
**Confidence:** EXTRACTED

---

## Transformation Contract

```
Array<ConversationTurn> → [TenorTracker.calculate_shifts] → Array<ConversationTurn> (mutated)
```

| Input | Output | Condition |
|-------|--------|-----------|
| `Array<ConversationTurn>` | Same array with `tenor_shift` filled | turns non-empty |
| Empty array | `[]` | no-op |

---

## Responsibilities

- Calculate tenor shifts between consecutive turns
- Detect significant shifts above threshold (default 0.15)
- Mutate turns in-place with shift values

---

## Key Components

| Component | Role |
|-----------|------|
| `initialize(turns, threshold:)` | Store turns array and shift threshold |
| `calculate_shifts` | Fill `tenor_shift` on each turn (mutates in-place) |
| `detect_significant_shifts` | Return shifts above threshold |

---

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `Types::ConversationTurn` | Input/output struct |

---

## Interactions

```mermaid
graph LR
    A[ConversationTurn[]] --> B[TenorTracker]
    B --> C[calculate_shifts]
    C --> D[ConversationTurn[] with tenor_shift]
    D --> E[ConversationAnalyzer.build_result]
```

---

## User/Developer Experience

**Developer** calls `TenorTracker.new(turns).calculate_shifts` and the turns array is mutated in-place with `tenor_shift` values.

**User** sees tenor shift values in analysis results and timeline visualizations.

---

## Known Limitations

1. **In-place mutation** — replaces structs in the `@turns` array rather than returning new objects
2. **Linear threshold** — fixed threshold may not suit all conversation types

---

## Design Rationale

Tenor shifts are calculated as simple difference between consecutive turns' average tenor scores. The threshold (0.15) was chosen to capture meaningful register changes without noise.

---

## Ruby Pragmatist Insight

> TenorTracker is a **temporal analyst** — it watches how formality rises and falls across a conversation, like a seismograph tracking social register. The mutations are intentional: the turns are the timeline, and the shifts are the tremors that reveal when participants shift from casual to formal, from intimate to distant.

---

## Trace Path

```
conversation_analyzer.rb:119  build_result
  └─► tenor_tracker.rb:10  calculate_shifts
       └─► tenor_tracker.rb:20  detect_significant_shifts
```
