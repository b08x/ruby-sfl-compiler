# Conversation Analysis: sample

**Generated**: 2026-06-13T00:25:25-04:00
**Turns**: 5 | **Speakers**: Alice, Bob

---

## ⚠️ Data Quality

**1 of 8 clauses (12.5%)** carry fallback/stub interpersonal values (tenor=0.5, modality=0.5, mood=declarative) instead of LLM annotations. Tenor and modality averages are biased toward 0.5.

---

## Summary

This analysis tracks **tenor evolution** (formality shifts), **field evolution** (topic/process changes), and **tenor ↔ field correlations** across the conversation.

---

## Speaker Profiles

| Speaker | Avg Tenor | Range | Variance | Avg Modality |
|---------|-----------|-------|----------|--------------|
| Alice   | 0.383 (mixed) | [0.0, 0.75] | 0.0939 | 0.333 |
| Bob     | 0.525 (mixed) | [0.5, 0.55] | 0.0006 | 0.325 |

---

## Cohesion Metrics

| Turn | Speaker | Repetition | Conjunctions | Pronouns |
|:-----|:---------|:-----------|:-------------|:---------|
| 1 | Alice | 0.0 | 0.0 | 0.071 |
| 2 | Bob | 0.0 | 0.0 | 0.133 |
| 3 | Alice | 0.0 | 0.0 | 0.083 |
| 4 | Bob | 0.0 | 0.0 | 0.235 |
| 5 | Alice | 0.0 | 0.0 | 0.125 |

---

## Tenor ↔ Field Correlations

| Process Type | Avg Tenor | Avg Modality | Count |
|--------------|-----------|--------------|-------|
| material | 0.5 | 0.433 | 3 |
| relational | 0.5 | 0.367 | 3 |
| mental | 0.5 | 0.25 | 2 |

---

## Generated Insights

1. Conversation tenor increased by 35.0% (more formal/distant)

2. Alice contributed 3 of 5 turns

### ⚡ Key Moments

- **Turn 3** (tenor shift): Formality decreased dramatically (+-0.5) between Bob and Alice
- **Turn 4** (tenor shift): Formality increased dramatically (+0.55) between Alice and Bob
- **Turn 5** (tenor shift): Formality increased dramatically (+0.2) between Bob and Alice
- **Turn 3** (modality shift): Certainty increased significantly (+0.4) in Alice's response

### 📖 Example Passages

#### Most Formal (score: 0.75)
> "Thanks! That would be really helpful."

*— Alice. Highest tenor (formality) score in the conversation.*

#### Most Casual (score: 0.0)
> "Yeah, it seems to be happening with refresh tokens specifically."

*— Alice. Lowest tenor score; uses informal register.*

#### Most Certain (score: 0.65)
> "I think I know what's going on. Let me check the token expiry logic."

*— Bob. Highest modality weight; assertive and definitive language.*

#### Most Hedged (score: 0.0)
> "Hey, I'm running into a weird issue with the auth flow."

*— Alice. Lowest modality weight; frequent use of hedging or uncertainty.*

---

## Methodology

**SFL Framework**: Two-Pass SFL Compiler (sfl-compiler)
- **Pass 1**: Syntactic parsing (spaCy) + Ideational extraction (process types, participants)
- **Pass 2**: Interpersonal annotation (DSPy.rb + LLM) → mood, modality, tenor, attitude

**Tenor Scale**: 0.0 (informal/casual) ↔ 1.0 (formal/technical)
**Modality Scale**: 0.0 (hedged/uncertain) ↔ 1.0 (certain/assertive)
