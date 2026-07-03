# SpeakerProfiler

**Location:** `lib/sfl/compiler/analysis/speaker_profiler.rb`
**Confidence:** EXTRACTED

---

## Transformation Contract

```
Array<ConversationTurn> → [SpeakerProfiler.build_profiles] → Array<SpeakerProfile>
```

| Input | Output | Condition |
|-------|--------|-----------|
| `Array<ConversationTurn>` | `Array<Types::SpeakerProfile>` | turns non-empty |
| Empty array | `[]` | no-op |

---

## Responsibilities

- Aggregate per-speaker linguistic patterns
- Calculate average tenor, modality, clause count
- Calculate variance for tenor and modality
- Identify dominant process types per speaker

---

## Key Components

| Component | Role |
|-----------|------|
| `build_profiles(turns)` | Class method: turns → speaker profiles |
| `variance(values)` | Calculate statistical variance |

---

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `Types::ConversationTurn` | Input struct |
| `Types::SpeakerProfile` | Output struct |

---

## Interactions

```mermaid
graph LR
    A[ConversationTurn[]] --> B[SpeakerProfiler]
    B --> C[Group by Speaker]
    C --> D[Calculate Averages]
    C --> E[Calculate Variance]
    D --> F[SpeakerProfile[]]
    E --> F
```

---

## User/Developer Experience

**Developer** calls `SpeakerProfiler.build_profiles(turns)` and receives an array of `SpeakerProfile` structs.

**User** sees speaker profiles in analysis results and markdown reports.

---

## Known Limitations

1. **No temporal analysis** — profiles are aggregate, not time-series
2. **Variance only** — no standard deviation or other statistics

---

## Design Rationale

Speaker profiles aggregate linguistic patterns across all turns by a speaker, providing a fingerprint of their communication style. Variance measures consistency vs. variability.

---

## Ruby Pragmatist Insight

> SpeakerProfiler is a **portrait artist** — it paints a linguistic portrait of each participant, capturing their typical register, certainty level, and dominant process types. The variance measure adds depth: a speaker with low variance is consistent; high variance reveals adaptability or volatility.

---

## Trace Path

```
conversation_analyzer.rb:119  build_result
  └─► speaker_profiler.rb:12  build_profiles
       └─► speaker_profiler.rb:63  variance
```
