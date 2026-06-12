# Two-Pass SFL Compiler

A Ruby gem for high-fidelity Retrieval-Augmented Generation (RAG) using
Systemic Functional Linguistics (SFL).

## Architecture

```
Raw Text
   │
   ▼
┌─────────────────────────────┐
│  PASS 1: Syntactic Engine   │
│  (ruby-spacy via PyCall)    │
│                             │
│  - Tokenization             │
│  - POS tagging              │
│  - Dependency parsing       │
│  - Sentence segmentation    │
│         │                   │
│         ▼                   │
│  Ideational Extractor       │
│  (rule-based)               │
│  - Process type             │
│  - Participants (roles)     │
│  - Circumstances            │
└──────────┬──────────────────┘
           │ SyntacticClause + IdeationalPayload
           ▼
┌─────────────────────────────┐
│  PASS 2: PassTwoEngine      │
│  (DSPy.rb + LLM)            │
│                             │
│  - Mood classification      │
│  - Modality weight (0-1)    │
│  - Tenor / formality (0-1)  │
│  - Speaker attitude         │
│                             │
│  Circuit breaker protected  │
└──────────┬──────────────────┘
           │ AnnotatedClause
           ▼
┌─────────────────────────────┐
│  Storage (PostgreSQL)       │
│                             │
│  clauses              (base)│
│  ideational_payloads  (P1)  │
│  interpersonal_payloads(P2) │
│  embeddings           (vec) │
│                             │
│  Scalar indices:            │
│    - mood                   │
│    - modality_weight        │
│    - tenor                  │
│    - process_type           │
│                             │
│  Vector index:              │
│    - ivfflat cosine         │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  Hybrid Retriever (RRF)     │
│                             │
│  Semantic (vector)          │
│       +                     │
│  Keyword (full-text)        │
│       │                     │
│  Reciprocal Rank Fusion     │
│       │                     │
│  + Scalar metadata filters  │
│    (mood, modality, tenor)  │
└─────────────────────────────┘
```

## Installation

Add to your Gemfile:

```ruby
gem "sfl-compiler"
```

Install dependencies:

```bash
# Python spaCy
pip install spacy
python -m spacy download en_core_web_sm

# PostgreSQL with pgvector
# (extension must be available in your database)
```

## Environment Configuration

Create a `.env` file in the project root (copy from `.env.example`):

```bash
# Database
DATABASE_URL=postgresql:///sfl_compiler_dev

# LLM Provider for Pass 2 (interpersonal annotation)
# Recommended: OpenRouter (one key, many models)
DSPY_PROVIDER=openrouter/mistralai/mistral-7b-instruct

# API Keys (only set what you're using)
OPENROUTER_API_KEY=sk-or-your-key-here
# OR
GOOGLE_API_KEY=your-key-here  # For google/gemini-2.0-flash-exp (FREE!)
# OR
OPENAI_API_KEY=sk-your-key-here
# OR
ANTHROPIC_API_KEY=your-key-here

# spaCy Model
SPACY_MODEL=en_core_web_sm
```

**Provider Options**:
- `openrouter/mistralai/mistral-7b-instruct` (recommended: fast & cheap)
- `openrouter/google/gemini-2.0-flash-exp` (FREE tier via OpenRouter!)
- `google/gemini-2.0-flash-exp` (FREE tier, native Gemini)
- `openrouter/mistralai/mixtral-8x7b-instruct` (better quality)
- `openai/gpt-4o-mini` (if you have OpenAI key)
- `anthropic/claude-3-5-sonnet-20241022` (if you have Anthropic key)

## Configuration

```ruby
require "sfl/compiler"

SFL::Compiler.configure do |c|
  c.database_url = "postgresql://localhost:5432/myapp_dev"
  c.spacy_model = "en_core_web_sm"
  c.dspy_provider = "openai/gpt-4o-mini"
  c.openai_api_key = ENV["OPENAI_API_KEY"]
end

# Configure DSPy.rb
DSPy.configure do |c|
  c.lm = DSPy::LM.new("openai/gpt-4o-mini",
    api_key: ENV["OPENAI_API_KEY"],
    structured_outputs: true)
end
```

## Usage

### Full Pipeline

```ruby
db = SFL::Compiler::Database.connect
SFL::Compiler::Database.setup_extensions(db)

pipeline = SFL::Compiler::Pipeline.new(db: db)
annotated = pipeline.compile(
  "The system processes user input and validates it against known patterns.",
  document_id: "doc-1"
)

annotated.each do |ac|
  puts "Text: #{ac.text}"
  puts "Process: #{ac.ideational.process_type}"
  puts "Mood: #{ac.interpersonal.mood}"
  puts "Modality: #{ac.interpersonal.modality_weight}"
  puts "Tenor: #{ac.interpersonal.tenor}"
  puts "---"
end
```

### Pass 1 Only (Batch Processing)

```ruby
pairs = pipeline.compile_pass_one("Your text here")
pairs.each do |clause, ideational|
  puts "#{ideational.process_type}: #{clause.text}"
end
```

### Retrieval with Scalar Filters

```ruby
retriever = SFL::Compiler::HybridRetriever.new(db: db)

# Retrieve only high-modality, formal technical documentation
results = retriever.retrieve(
  "input validation",
  filters: {
    min_modality: 0.7,
    min_tenor: 0.5,
    process_type: "material"
  }
)
```

### Conversation Analysis

Analyze chat logs for tenor evolution, speaker patterns, and rhetorical correlations:

```bash
# Run via the sfl-analyze CLI
bundle exec sfl-analyze conversation conversation.jsonl --output-dir ./output

# Or use the Claude Code skill
/sfl-analyze conversation conversation.jsonl
```

**Input Format** (JSONL):
```jsonl
{"name":"Alice","send_date":"June 10, 2026 2:30pm","mes":"Message text..."}
{"name":"Bob","send_date":"June 10, 2026 2:31pm","mes":"Response text..."}
```

**Outputs**:
- `conversation_analysis.csv` — Turn-by-turn data (speaker, tenor, modality, process types)
- `conversation_analysis.json` — Structured analysis data
- `conversation_analysis.md` — Human-readable report with insights

**Analysis Features**:
- **Tenor Tracking**: Detect formality shifts across conversation
- **Speaker Profiling**: Aggregate tenor/modality/mood per speaker
- **Process Correlation**: Link process types (mental/verbal/material) with rhetorical stance
- **Insight Generation**: Automated observations about communication patterns

**Example Insights**:
- "Steve maintains 2.0x higher tenor (0.76) than Robert (0.38)"
- "Mental processes correlate with casual tenor (0.34)"
- "Largest tenor shift at turn #2: Δ = +0.46"

### Database Setup

```ruby
db = SFL::Compiler::Database.connect
SFL::Compiler::Migrator.new(db).run_all
```

## Payload Separation

The system separates SFL metafunctions into distinct database tables:

| Table | Source | Content |
|-------|--------|---------|
| `clauses` | Pass 1 | Raw text, tokens, dependency tree |
| `ideational_payloads` | Pass 1 | Process type, participants, circumstances |
| `interpersonal_payloads` | Pass 2 | Mood, modality_weight, tenor, attitude |
| `embeddings` | Embedder | Vector embeddings for semantic search |

## Scalar Filtering

The Interpersonal payload supports scalar metadata filtering:

- **Modality Weight** (0.0-1.0): Strength of certainty
  - "must" = 0.9, "should" = 0.7, "might" = 0.3
- **Tenor** (0.0-1.0): Formality of register
  - Technical documentation = 0.8, casual blog = 0.2
- **Mood**: declarative, interrogative, imperative, exclamative

## License

MIT
