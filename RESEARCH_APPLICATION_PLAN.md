# Applying Research Theories to SFL Compiler Framework

**Based on**: Your Notebook research documents
- `Integrating SFL, FCA, and ID3 Decision Trees`
- `SFL as LLM Compiler`
- `Optimizing Text with SFL Analysis`

---

## Key Theories to Implement

### 1. **SFL + FCA + ID3 Integration** (From Notebook Research)

**The Theory**:
Combine three methodologies:
1. **SFL** provides semantically rich features from linguistic analysis
2. **FCA (Formal Concept Analysis)** structures these features into conceptual lattices
3. **ID3 Decision Trees** classify responses and select most informative linguistic features

**Current Implementation Status**:
- ✅ SFL Pass 1 (spaCy Transitivity extraction) - DONE
- ✅ SFL Pass 2 (LLM Interpersonal annotation) - DONE
- ❌ FCA integration - NOT STARTED
- ❌ ID3 decision tree analysis - NOT STARTED

**What This Would Enable**:
- Discover hidden patterns in conversation data
- Classify speakers by linguistic style
- Identify most informative SFL features automatically
- Reduce feature space intelligently (not all 6 process types matter equally)

### 2. **SFL as LLM Compiler** (From Your Essay)

**The Theory**:
- **Ideational = World Modeling** (what we're talking about)
- **Interpersonal = Persona/Alignment** (who we are, how certain)
- **Textual = Attention Weights** (Theme guides Key/Value tensors)

**Current Implementation Status**:
- ✅ Ideational (Process types via Transitivity) - DONE
- ✅ Interpersonal (Tenor, Modality via DSPy LLM) - DONE
- ⚠️ Textual (Theme/Rheme, Cohesion) - PARTIAL (not yet extracted)

**What's Missing**:
```ruby
# lib/sfl/compiler/pass_one/ideational_extractor.rb
# MISSING: Theme/Rheme extraction
# MISSING: Cohesion analysis (reference, conjunction, lexical)
```

**What This Would Enable**:
- Understand HOW messages are organized (not just WHAT they say)
- Track Topic shifts (Theme changes)
- Measure text flow quality (Cohesion density)
- Apply to prompt engineering (Theme = instruction placement)

### 3. **Register Analysis** (Field, Tenor, Mode)

**The Theory**:
- **Field**: What's being discussed (topic/activity)
- **Tenor**: Relationship between speakers (formality, power)
- **Mode**: Communication channel (written/spoken, interactive/monologic)

**Current Implementation**:
- ✅ Tenor (formality) tracked per turn
- ❌ Field (topic clustering) - NOT IMPLEMENTED
- ❌ Mode (channel characteristics) - NOT IMPLEMENTED

**What's Missing**:
Need to automatically detect:
- Field shifts (topic changes within conversation)
- Mode characteristics (e.g., synchronous vs async, formal vs casual channel)
- Register consistency (does Field match Tenor? formal topic + casual language = mismatch)

---

## Enhancement Roadmap

### Phase 1: Complete Textual Metafunction (This Week)

**Goal**: Extract Theme/Rheme and Cohesion features

**Implementation**:
1. **Theme/Rheme Extraction** (Pass 1 addition)
   ```ruby
   # lib/sfl/compiler/pass_one/textual_extractor.rb
   class TextualExtractor
     def extract_theme(clause_spacy_doc)
       # Topical Theme: typically first nominal/verbal group
       # Textual Theme: conjunctions, connectives
       # Interpersonal Theme: modal Adjuncts
       {
         topical_theme: identify_topical(clause),
         textual_theme: identify_textual(clause),
         interpersonal_theme: identify_interpersonal(clause),
         rheme: remainder
       }
     end
   end
   ```

2. **Cohesion Analysis** (Pass 1 addition)
   ```ruby
   # lib/sfl/compiler/pass_one/cohesion_analyzer.rb
   class CohesionAnalyzer
     def analyze(clauses_array)
       {
         reference_chains: track_pronouns_and_demonstratives,
         conjunction_types: categorize_connectives,  # causal, temporal, additive
         lexical_cohesion: {
           repetition: count_repeated_words,
           synonymy: detect_near_synonyms,
           collocation: find_word_pairs
         }
       }
     end
   end
   ```

3. **Storage Schema Update**
   ```sql
   ALTER TABLE clauses ADD COLUMN topical_theme TEXT;
   ALTER TABLE clauses ADD COLUMN textual_theme TEXT;
   ALTER TABLE clauses ADD COLUMN rheme TEXT;
   ALTER TABLE clauses ADD COLUMN cohesion_score FLOAT;
   ```

### Phase 2: FCA Integration (Next Week)

**Goal**: Apply Formal Concept Analysis to discover patterns

**Gem**: `rubyfca` (you mentioned it in your research)

**Implementation**:
1. **SFL Features → FCA Attributes**
   ```ruby
   # lib/sfl/compiler/analysis/fca_adapter.rb
   class FCAAdapter
     def build_formal_context(turns)
       objects = turns.map(&:turn_id)
       attributes = extract_sfl_attributes(turns)
       
       # Example attributes:
       # - process_type=material
       # - mood=declarative
       # - modality_weight>0.7
       # - has_modal_obligation
       # - theme_type=marked
       
       RubyFCA::FormalContext.new(objects, attributes, incidence_matrix)
     end
   end
   ```

2. **Concept Lattice Generation**
   ```ruby
   # Generate lattice showing clusters of similar turns
   lattice = fca_adapter.generate_lattice(turns)
   
   # Find:
   # - Which SFL features co-occur?
   # - Which turns form coherent functional groups?
   # - What's the hierarchy? (formal → casual, certain → hedged)
   ```

3. **Attribute Implications**
   ```ruby
   # Discover rules like:
   # IF process=mental THEN modality<0.6 (hedging with introspection)
   # IF mood=imperative THEN tenor>0.6 (commands are formal)
   
   implications = lattice.extract_implications
   ```

### Phase 3: ID3 Decision Tree Analysis (Next Week)

**Goal**: Classify speakers and select most informative features

**Gem**: `decisiontree` by Ilya Grigorik

**Implementation**:
1. **Speaker Classification**
   ```ruby
   # lib/sfl/compiler/analysis/speaker_classifier.rb
   class SpeakerClassifier
     def train(turns)
       # Attributes: all SFL features (process_type, mood, modality, tenor, etc.)
       # Class label: speaker name
       
       tree = DecisionTree::ID3Tree.new(
         attribute_names,
         training_data,
         default_speaker,
         :discrete
       )
       tree.train
       
       # Result: "What linguistic patterns best distinguish speakers?"
       # E.g., "Robert uses material processes + low modality"
       #       "Steve uses relational processes + high modality"
     end
   end
   ```

2. **Feature Importance Ranking**
   ```ruby
   # Which SFL features matter most?
   feature_importance = tree.feature_importance
   # Output:
   # 1. modality_weight (0.45 importance)
   # 2. process_type (0.32)
   # 3. mood (0.15)
   # 4. theme_type (0.08)
   
   # Use this to:
   # - Simplify future analyses (drop low-importance features)
   # - Focus LLM annotation on high-value features
   # - Understand what REALLY differentiates speakers
   ```

3. **Topic Detection** (Field Analysis)
   ```ruby
   # Classify turns by topic using process participants
   topic_tree = DecisionTree::ID3Tree.new(
       ['process_type', 'participant_lemmas', 'tenor'],
       turns_with_manual_topic_labels,  # training set
       'general',
       :discrete
   )
   
   # Predict topics for unlabeled turns
   predicted_topics = unlabeled_turns.map { |t| topic_tree.predict(t.features) }
   ```

### Phase 4: Enhanced Formatters (After Phase 1-3)

**Goal**: Generate insights humans actually understand

**Implementation**:
1. **Plain English Insight Generator**
   ```ruby
   # lib/sfl/compiler/analysis/insight_generator.rb
   class InsightGenerator
     def generate(analysis_result, fca_lattice, decision_tree)
       insights = []
       
       # Communication styles
       insights << describe_speaker_styles(analysis_result.speaker_profiles)
       # "Robert: casual language (tenor 0.42), action-focused (58% material), moderate certainty"
       
       # Formality evolution
       insights << describe_tenor_evolution(analysis_result.tenor_timeline)
       # "Conversation became 23% more formal from turn 5 to turn 15"
       
       # Pattern discovery from FCA
       insights << describe_fca_concepts(fca_lattice)
       # "3 distinct communication modes detected:
       #  1. Technical discussion (material + high modality)
       #  2. Exploratory thinking (mental + low modality)  
       #  3. Social coordination (verbal + medium modality)"
       
       # Feature importance from ID3
       insights << describe_key_features(decision_tree)
       # "Modality (certainty) is THE key differentiator between speakers,
       #  3x more important than vocabulary choice"
       
       insights
     end
   end
   ```

2. **Example Passages Section**
   ```ruby
   def show_example_passages(turns, analysis_result)
     examples = []
     
     # Most formal
     most_formal = turns.max_by(&:avg_tenor)
     examples << {
       label: "Most Formal (tenor: #{most_formal.avg_tenor.round(2)})",
       text: most_formal.message_text[0..100],
       why: "Uses relational processes, no hedging, technical vocabulary"
     }
     
     # Most casual
     most_casual = turns.min_by(&:avg_tenor)
     examples << {
       label: "Most Casual (tenor: #{most_casual.avg_tenor.round(2)})",
       text: most_casual.message_text[0..100],
       why: "Material processes, contractions, personal pronouns"
     }
     
     # Most uncertain
     most_uncertain = turns.min_by(&:avg_modality)
     examples << {
       label: "Most Uncertain (modality: #{most_uncertain.avg_modality.round(2)})",
       text: most_uncertain.message_text[0..100],
       why: "Hedging ('maybe', 'possibly'), interrogative mood, low commitment"
     }
     
     examples
   end
   ```

3. **Key Moments Detection**
   ```ruby
   def detect_key_moments(turns)
     moments = []
     
     # Significant tenor shifts
     turns.each_cons(2) do |prev_turn, curr_turn|
       shift = curr_turn.avg_tenor - prev_turn.avg_tenor
       if shift.abs > 0.15
         moments << {
           type: :tenor_shift,
           magnitude: shift,
           from_text: prev_turn.message_text[0..50],
           to_text: curr_turn.message_text[0..50],
           interpretation: shift > 0 ? "Became more formal" : "Became more casual"
         }
       end
     end
     
     # Topic changes (via Theme shift + participant change)
     # Mood changes (declarative → imperative = taking control)
     # Modality changes (hedged → certain = confidence gained)
     
     moments
   end
   ```

---

## Implementation Priority

**Week 1** (Core Enhancements):
1. ✅ Theme/Rheme extraction (Textual metafunction completion)
2. ✅ Cohesion analysis
3. ✅ Enhanced Markdown formatter with examples & key moments
4. ✅ InsightGenerator class

**Week 2** (Advanced Analysis):
5. FCA integration (`rubyfca` gem)
6. Concept lattice generation
7. Attribute implications discovery

**Week 3** (Machine Learning):
8. ID3 decision tree integration (`decisiontree` gem)
9. Speaker classification
10. Feature importance ranking
11. Automated topic detection

**Week 4** (Validation & Documentation):
12. Test on multiple conversation types
13. Validate against manual analysis
14. Document discovered patterns
15. Create analysis cookbook

---

## Expected Outcomes

### What You'll Be Able to Do

**Question**: "Find conversations where I was most uncertain about consciousness"

**Answer**:
```
3 conversations found:
1. 2025-03-15 Philosophy discussion (avg modality: 0.32)
   - High mental processes (thinking, believing)
   - Frequent interrogatives
   - Hedging patterns: "perhaps", "might be", "possibly"
   - Example: "Maybe consciousness emerges from... or does it?"

2. 2025-04-02 AI ethics debate (avg modality: 0.38)
   ...
```

**Question**: "How did my writing style change from Jan to Jun 2026?"

**Answer**:
```
Temporal Analysis (6 months):

Formality Evolution:
- Jan: 0.42 tenor (casual, exploratory)
- Jun: 0.58 tenor (formal, authoritative) [+38%]

Process Type Shift:
- Jan: 45% mental, 35% material (thinking/doing)
- Jun: 28% mental, 52% relational (defining/explaining) 
→ Shifted from exploration to documentation

Modality Trend:
- Jan: 0.48 (hedged, uncertain)
- Jun: 0.72 (certain, assertive) [+50%]

Key Moment: March 2026
- Dramatic shift detected between Mar 15-20
- Formality jumped +0.25 in 5 days
- Trigger: First published paper (confidence boost)
```

**Question**: "Which linguistic features best predict topic?"

**Answer** (from ID3):
```
Decision Tree Analysis:

Feature Importance for Topic Prediction:
1. Participant lemmas (0.65) - MOST IMPORTANT
   → Nouns/verbs matter more than structure
2. Process type (0.22)
   → Material = technical, Mental = philosophy
3. Modality (0.10)
   → Certainty correlates with familiar topics
4. Mood (0.03) - LEAST IMPORTANT
   → Doesn't predict topic well

Discovered Rules:
IF participants contain ["neural", "network", "embedding"]
   THEN topic = "AI/ML" (98% confidence)

IF process=mental AND modality<0.5
   THEN topic = "Philosophy" (87% confidence)

IF process=material AND tenor>0.7
   THEN topic = "Technical Documentation" (94% confidence)
```

---

## Success Metrics

You'll know this is working when:

1. **Automatic Pattern Discovery**: FCA lattice shows 3-5 distinct "communication modes" you didn't explicitly define
2. **Feature Reduction**: ID3 identifies that 4-5 SFL features explain 80%+ of variation
3. **Interpretable Insights**: Non-technical humans can understand what the analysis tells them
4. **Predictive Power**: Can classify new text by author/topic with >85% accuracy
5. **Research Validation**: Your own theories (SFL as LLM Compiler) are empirically validated

---

## Next Immediate Steps

1. Read your full research documents into context
2. Extract concrete FCA examples (formal context structure)
3. Extract ID3 Ruby code examples
4. Start with Theme/Rheme extractor (simplest addition)
5. Test on steve-oliver conversation (we already have results to compare)

Ready to start implementing? Which phase should we tackle first?
