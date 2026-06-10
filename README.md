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
