# SFL Analysis of Notebook Collection - Implementation Plan

## Goal
Apply Systemic Functional Linguistics analysis to 2,780 markdown files to understand:
1. **Your writing evolution** (tenor shifts over time)
2. **Topic-specific language patterns** (field analysis by folder/tag)
3. **Different writing modes** (journal vs technical vs reflective)
4. **Rhetorical strategies** (how you explain, persuade, document)

## Discovered Content Types

Based on QMD search:
- **Reflective/Journal entries** (`Philosophy/`, `archive/`)
- **Technical documentation** (`Prompt-Library-V2/`)
- **AI/LLM explorations** (`GenAI/`)
- **Process documentation** (thinking processes, meta-cognition)

## Phase 1: Sample Analysis (Tonight)

### 1.1 Extract Representative Samples

```bash
# Get 50 documents across different categories
qmd multi-get "Notebook/Philosophy/**/*.md" -l 10 > samples/philosophy.md
qmd multi-get "Notebook/archive/2025/**/*.md" -l 10 > samples/journal_2025.md
qmd multi-get "Notebook/Prompt-Library-V2/**/*.md" -l 10 > samples/prompts.md
qmd multi-get "Notebook/GenAI/**/*.md" -l 10 > samples/genai.md
```

### 1.2 Convert to JSONL Format

Create a script to convert markdown files to conversation-style JSONL:
```ruby
# scripts/markdown_to_jsonl.rb
# Treats each document as a "turn" with metadata
{
  "name": "Author",  # Your name
  "is_user": true,
  "send_date": file_mtime,
  "mes": markdown_content,
  "extra": {
    "path": file_path,
    "category": folder_name,
    "word_count": words
  }
}
```

### 1.3 Run SFL Analysis

```bash
/sfl-analyze conversation samples/philosophy.jsonl --output-dir results/philosophy
/sfl-analyze conversation samples/journal_2025.jsonl --output-dir results/journal
/sfl-analyze conversation samples/prompts.jsonl --output-dir results/prompts
```

### 1.4 Compare Results

Key questions:
- **Philosophy docs**: Higher tenor (formal) or more hedging (low modality)?
- **Journal entries**: Personal (low tenor) vs analytical (high modality)?
- **Prompt docs**: Imperative mood? Process type distribution?

## Phase 2: Temporal Analysis (This Week)

### 2.1 Chronological Sampling

Extract documents by month:
```bash
for month in 2025-{01..06}; do
  qmd multi-get "Notebook/archive/2025/$month/**/*.md" -l 20 > temporal/$month.jsonl
done
```

### 2.2 Tenor Evolution Over Time

Run analysis per month, plot:
- Average tenor trend (getting more/less formal?)
- Modality trend (more/less certain?)
- Process type shifts (action → reflection?)

### 2.3 Generate Insights

- "Your writing became 15% more formal from Jan to Jun 2025"
- "Mental processes (thinking, knowing) increased 23% in March"
- "Verbal processes (discussing, explaining) peaked in May"

## Phase 3: Topic-Driven Analysis (Next Week)

### 3.1 Use QMD to Group by Topic

```bash
# Philosophy & Consciousness
qmd query -c Notebook 'consciousness awareness reflection' -l 100

# Technical/System Documentation  
qmd query -c Notebook 'implementation architecture system' -l 100

# Process & Methodology
qmd query -c Notebook 'process workflow methodology' -l 100
```

### 3.2 Field Analysis Per Topic

Compare process type distributions:
- **Philosophy**: Mental (66%), Relational (20%), Verbal (14%)?
- **Technical**: Material (55%), Relational (30%), Mental (15%)?
- **Process docs**: Material (60%), Verbal (25%), Mental (15%)?

### 3.3 Rhetorical Stance Filtering

Use SFL to find documents by HOW you wrote them:
```sql
-- Find highly certain, formal technical docs
SELECT * FROM clauses 
WHERE tenor > 0.7 
  AND modality_weight > 0.7 
  AND process_type = 'material'

-- Find uncertain, exploratory journal entries
SELECT * FROM clauses
WHERE tenor < 0.4
  AND modality_weight < 0.5
  AND mood = 'interrogative'
```

## Phase 4: Enhanced Markdown Formatter (Tonight)

### 4.1 Add Interpretation Layer

Enhance `lib/sfl/compiler/formatters/markdown_formatter.rb` to include:

```ruby
def interpretation_section
  <<~INTERPRETATION
  ## What This Means

  #{explain_tenor_patterns}
  
  #{explain_certainty_patterns}
  
  #{explain_language_patterns}
  
  #{show_example_passages}
  INTERPRETATION
end
```

### 4.2 Example Passages

Show actual text with annotations:
```markdown
### Most Formal Passage (tenor: 0.85)
> "The implementation leverages architectural principles to ensure system coherence..."

### Most Casual Passage (tenor: 0.23)
> "So yeah, I'm thinking this whole thing just kinda works if we..."

### Most Certain Passage (modality: 0.92)
> "This definitively establishes the core mechanism..."

### Most Uncertain Passage (modality: 0.18)
> "Maybe there's something here, possibly worth exploring..."
```

### 4.3 Key Moments Section

```markdown
## Significant Shifts

**Entry 15 → Entry 16** (+0.35 tenor)
From: "playing around with this idea..."
To: "The systematic analysis demonstrates..."
→ Shift from exploration to documentation mode
```

## Phase 5: Plain English Summary Generator (Tomorrow)

### 5.1 Create InsightGenerator Class

```ruby
# lib/sfl/compiler/analysis/insight_generator.rb
class InsightGenerator
  def generate_plain_english(analysis_result)
    - Speaker communication styles
    - Formality evolution
    - Topic-language correlations  
    - Notable patterns (all imperatives, no hedging, etc.)
    - Comparison to norms ("30% more formal than typical")
  end
end
```

### 5.2 Add to Analysis Result

Auto-generate insights like:
- "This writing shows high certainty (0.68 avg modality) but casual formality (0.42 tenor) - confident but friendly"
- "Mental processes dominate (58%) - introspective, analytical writing"
- "7 significant tenor shifts detected - switches between reflection and documentation modes"

## Implementation Priority

**Tonight** (2 hours):
1. ✅ Create markdown_to_jsonl converter
2. ✅ Extract 50 sample documents from Notebook
3. ✅ Run sample analysis
4. ✅ Enhance Markdown formatter with interpretation

**Tomorrow** (3 hours):
5. Create InsightGenerator class
6. Add example passages to output
7. Generate first "What This Tells You" report

**This Week**:
8. Temporal analysis (writing evolution over time)
9. Topic-driven field analysis
10. Database querying examples (rhetorical stance filtering)

## Expected Discoveries

Based on the QMD search showing reflective/analytical content:

**Hypothesis 1**: Philosophy docs will show:
- High mental process % (thinking, knowing, believing)
- Lower modality (hedging, exploring, questioning)
- Mixed tenor (formal concepts, casual exploration)

**Hypothesis 2**: Prompt Library docs will show:
- High material + verbal processes (instructions)
- Imperative mood dominance
- Higher modality (directive, certain)

**Hypothesis 3**: Journal entries will show:
- Temporal tenor shifts (casual → formal as you work things out)
- Mixed process types (mental for thinking, material for doing)
- Modality shifts (uncertain → certain as clarity emerges)

## Tools & Scripts Needed

1. `scripts/markdown_to_jsonl.rb` - Convert MD to conversation format
2. `scripts/batch_analyze_collection.rb` - Process entire collection
3. `scripts/temporal_analysis.rb` - Group by date, track trends
4. `scripts/topic_clustering.rb` - QMD search + SFL analysis
5. Enhanced formatters for better output

## Success Criteria

You'll know it's working when you can:
1. **Ask**: "Find my most uncertain writing about consciousness"
2. **Ask**: "Show how my formality changed from Jan to Jun"
3. **Ask**: "Which topics do I write most confidently about?"
4. **Get**: Actual passages with annotations explaining WHY they match

This transforms your Notebook from a pile of markdown into a **linguistically-queryable knowledge base**!
