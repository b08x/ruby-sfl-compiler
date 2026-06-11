# SFL Compiler Experiments

**Status**: Beta / Research / Theory Testing

These are throwaway scripts to validate theories from Notebook research before committing to architecture.

## Quick Experiments

### 1. Does FCA reveal patterns? (30 minutes)

**Test**: Can we find hidden speaker clusters using existing SFL features?

```bash
# Use existing analysis results
ruby experiments/01_fca_proof_of_concept.rb sfl_output_mimo/conversation_analysis.json
```

**Expected Output**:
```
Formal Context: 29 turns × 12 SFL attributes
Concept Lattice Generated: 8 concepts

Discovered Clusters:
  Concept 1: High modality + Material processes (Steve's action-focused style)
  Concept 2: Low modality + Mental processes (Robert's reflective style)
  Concept 3: Mixed...

Attribute Implications:
  IF mood=imperative THEN tenor>0.5 (commands are formal)
  IF process=mental THEN modality<0.6 (thinking is uncertain)
```

**Decision Point**: Do the clusters make sense? If YES → continue. If NO → theory is wrong.

---

### 2. Does ID3 identify key features? (20 minutes)

**Test**: Which SFL features best predict speaker?

```bash
ruby experiments/02_id3_feature_importance.rb sfl_output_mimo/conversation_analysis.json
```

**Expected Output**:
```
Decision Tree Depth: 3
Accuracy: 87% (cross-validated)

Feature Importance:
  1. modality_weight: 0.52  ← MOST IMPORTANT
  2. process_type: 0.31
  3. mood: 0.12
  4. tenor: 0.05  ← LEAST IMPORTANT

Decision Rules:
  IF modality > 0.55 THEN speaker=Steve (94% confidence)
  IF modality <= 0.55 AND process=material THEN speaker=Robert (78%)
```

**Decision Point**: Does modality really matter most? Surprising? If insights are interesting → theory works.

---

### 3. Can we extract Theme/Rheme? (45 minutes)

**Test**: Is Theme extraction feasible with spaCy?

```bash
ruby experiments/03_theme_rheme_extractor.rb "The implementation leverages architectural principles"
```

**Expected Output**:
```
Clause: "The implementation leverages architectural principles"

Theme Analysis:
  Topical Theme: "The implementation" (Subject in declarative)
  Textual Theme: (none)
  Interpersonal Theme: (none)
  Rheme: "leverages architectural principles"

Theme Type: Unmarked topical (typical for declarative)
```

**Decision Point**: Can spaCy identify Subject reliably? If YES → build it. If NO → need different approach.

---

### 4. Does cohesion correlate with anything? (30 minutes)

**Test**: Do turns with high lexical cohesion have different tenor?

```bash
ruby experiments/04_cohesion_correlation.rb sfl_output_mimo/conversation_analysis.json
```

**Expected Output**:
```
Cohesion Metrics per Turn:
  Turn 1: repetition=0.2, tenor=0.45
  Turn 2: repetition=0.4, tenor=0.52
  ...

Correlations:
  Repetition ↔ Tenor: -0.32 (weak negative)
  → More repetition = LESS formal (casual recap)
  
  Conjunction density ↔ Modality: 0.58 (moderate positive)
  → More connectives = MORE certain (structured argument)
```

**Decision Point**: Are correlations meaningful? If YES → cohesion matters. If NO → skip it.

---

## Experiment Scripts (Simple, Throwaway)

All scripts:
- ✅ Use existing analysis results (no re-parsing)
- ✅ Single-file, < 100 lines
- ✅ Print results to STDOUT (no databases)
- ✅ Answer ONE question clearly
- ❌ No abstraction
- ❌ No error handling
- ❌ No production code

---

## Decision Tree

```
Run Experiments → Results → Decision
    ↓              ↓         ↓
 1hr work    Interesting?  YES → Productionize
                   ↓        NO → Discard theory
                Boring?
```

If experiments show nothing interesting → **don't build it**.  
If experiments reveal cool patterns → **then** build the framework.

---

## Next Steps

1. ✅ Write 4 throwaway experiment scripts
2. ⏳ Run on steve-oliver conversation
3. ⏳ Examine results
4. ⏳ **DECIDE** what to build (if anything)

Let's validate theories before architecture.
