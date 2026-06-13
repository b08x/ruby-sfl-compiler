# Conversation Analysis: sample

**Generated**: 2026-06-13T00:29:24-04:00
**Turns**: 5 | **Speakers**: Alice, Bob

---

## ⚠️ Data Quality

**2 of 8 clauses (25.0%)** carry fallback/stub interpersonal values (tenor=0.5, modality=0.5, mood=declarative) instead of LLM annotations. Tenor and modality averages are biased toward 0.5.

---

## Summary

This analysis tracks **tenor evolution** (formality shifts), **field evolution** (topic/process changes), and **tenor ↔ field correlations** across the conversation.

---

## Speaker Profiles

| Speaker | Avg Tenor | Range | Variance | Avg Modality |
|---------|-----------|-------|----------|--------------|
| Alice   | 0.417 (mixed) | [0.2, 0.55] | 0.0239 | 0.417 |
| Bob     | 0.75 (formal) | [0.75, 0.75] | 0.0 | 0.275 |

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
| material | 0.567 | 0.267 | 3 |
| relational | 0.6 | 0.333 | 3 |
| mental | 0.65 | 0.4 | 2 |

---

## Generated Insights

1. Alice contributed 3 of 5 turns

### ⚡ Key Moments

- **Turn 2** (tenor shift): Formality increased dramatically (+0.25) between Alice and Bob
- **Turn 3** (tenor shift): Formality decreased dramatically (+-0.55) between Bob and Alice
- **Turn 4** (tenor shift): Formality increased dramatically (+0.55) between Alice and Bob
- **Turn 5** (tenor shift): Formality decreased dramatically (+-0.2) between Bob and Alice

### 📖 Example Passages

#### Most Formal (score: 0.75)
> "Hmm, that's strange. Are you seeing any patterns in the logs?"

*— Bob. Highest tenor (formality) score in the conversation.*

#### Most Casual (score: 0.2)
> "Yeah, it seems to be happening with refresh tokens specifically."

*— Alice. Lowest tenor score; uses informal register.*

#### Most Certain (score: 0.5)
> "Hey, I'm running into a weird issue with the auth flow."

*— Alice. Highest modality weight; assertive and definitive language.*

#### Most Hedged (score: 0.25)
> "Hmm, that's strange. Are you seeing any patterns in the logs?"

*— Bob. Lowest modality weight; frequent use of hedging or uncertainty.*

---

## Methodology

**SFL Framework**: Two-Pass SFL Compiler (sfl-compiler)
- **Pass 1**: Syntactic parsing (spaCy) + Ideational extraction (process types, participants)
- **Pass 2**: Interpersonal annotation (DSPy.rb + LLM) → mood, modality, tenor, attitude

**Tenor Scale**: 0.0 (informal/casual) ↔ 1.0 (formal/technical)
**Modality Scale**: 0.0 (hedged/uncertain) ↔ 1.0 (certain/assertive)
