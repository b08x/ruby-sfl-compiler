# Two-Pass SFL Compiler — Framework Knowledge Base

## What It Is

A Ruby gem that compiles natural language into structured SFL (Systemic Functional Linguistics) annotations for high-fidelity RAG. Two passes: Pass 1 extracts syntactic structure and ideational content using spaCy; Pass 2 annotates interpersonal features (mood, modality, tenor) using an LLM via DSPy.rb.

The core insight: separating syntax from semantics lets you filter retrieval results on *rhetorical stance*, not just topic. You can query for "high-certainty declarative statements about authentication" and actually get that back.

## Architecture

```
MarkdownLoader → Pipeline → PassOneEngine → IdeationalExtractor
                                        ↓
                                   PassTwoEngine (DSPy.rb)
                                        ↓
                              ClauseRepository (store)
                              EmbeddingRepository (embed)
                                        ↓
                              HybridRetriever (RRF)
```

### Pass 1 — Syntactic Engine (`PassOneEngine` + `IdeationalExtractor`)

**Input:** Raw text (or a `MarkdownLoader::Section`)  
**Output:** `Array<SyntacticClause>` + `Array<IdeationalPayload>`

`PassOneEngine` calls `Spacy::Language.new(model).read(text)` once per section. Sentence boundaries come from `doc.sents` — one PyCall round-trip, no separate sentence segmenter. Each token gets `text`, `lemma`, `pos`, `tag`, `dep`, `head_index`, `morphology`.

`IdeationalExtractor` is pure Ruby, no LLM. It classifies:
- **Process type** — material / mental / relational / verbal / behavioral / existential
- **Participants** — Actor, Goal, Recipient, Attribute (from dependency labels)
- **Circumstances** — prepositional modifiers, adverbials

The classification is lemma-based: a verb like "know" → mental, "be" → relational, "say" → verbal. Everything else falls through to the POS-tag default (material).

### Pass 2 — Semantic Annotator (`PassTwoEngine`)

**Input:** `SyntacticClause` + `IdeationalPayload`  
**Output:** `AnnotatedClause`

Uses DSPy.rb `ChainOfThought` with a typed `SFLSignature`. The LLM gets the syntactic context (root verb, process type, participants, POS/dep sequences) and returns:

| Field | Type | Range/Values |
|-------|------|--------------|
| `mood` | enum | declarative, interrogative, imperative, exclamative |
| `modality_weight` | float | 0.0 (hedged) – 1.0 (certain) |
| `tenor` | float | 0.0 (informal) – 1.0 (formal) |
| `speaker_attitude` | string | neutral, positive, negative, skeptical, assertive |
| `reasoning` | string | ChainOfThought explanation |

Circuit breaker wraps the DSPy call. When open, defaults to mood=declarative, modality=0.5, tenor=0.5. The default breaker is a pass-through lambda — substitute a real one when you have production failure data.

### Storage — PostgreSQL + pgvector

Four tables, created by `Migrator#run_all`:

| Table | Stores | Key columns |
|-------|--------|-------------|
| `clauses` | Base text, token JSONB | `external_id` (UUID), `document_id`, `tokens` |
| `ideational_payloads` | Pass 1 output | `process_type`, `participants` (jsonb), `circumstances` |
| `interpersonal_payloads` | Pass 2 output | `mood`, `modality_weight`, `tenor` |
| `embeddings` | Vectors | `clause_id`, `embedding vector(768)`, `model` |

Scalar indices on `interpersonal_payloads(mood, modality_weight, tenor)` for filtering. Vector index on `embeddings(embedding)` using ivfflat cosine. GIN index on `clauses.tokens` for JSONB queries.

### Retrieval — Hybrid RRF (`HybridRetriever`)

Two searches run in parallel conceptually:

1. **Semantic** — `embedding <=> query_embedding` (pgvector cosine)
2. **Keyword** — `to_tsvector @@ plainto_tsquery` (full-text)

Results merge with Reciprocal Rank Fusion: `score(d) = 1/(60 + rank_semantic) + 1/(60 + rank_keyword)`. Then scalar filters apply (mood, modality range, tenor range, process type).

## Data Types

All value objects are `Dry::Struct` with constrained types. Key ones:

- `Types::SyntacticToken` — single token with POS, dep, morphology
- `Types::SyntacticClause` — sentence-level: text + token array + root index
- `Types::IdeationalPayload` — process_type (enum), participants, circumstances
- `Types::InterpersonalPayload` — mood (enum), modality_weight (0–1), tenor (0–1)
- `Types::AnnotatedClause` — full output: syntactic + ideational + interpersonal + timestamp

## Configuration

```ruby
SFL::Compiler.configure do |c|
  c.database_url  = "postgresql:///sfl_dev"  # required
  c.spacy_model   = "en_core_web_sm"          # default
  c.dspy_provider = "openai/gpt-4o-mini"      # default
end

# DSPy.rb must be configured separately:
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
SFL::Compiler::Migrator.new(db).run_all

pipeline = SFL::Compiler::Pipeline.new(db: db)

annotated = pipeline.compile(
  "The system validates each request against the schema.",
  document_id: "doc-1"
)

annotated.each do |ac|
  puts "#{ac.ideational.process_type} | #{ac.interpersonal.mood} | mod=#{ac.interpersonal.modality_weight}"
  # => "material | declarative | mod=0.85"
end
```

### Pass 1 Only (No LLM Cost)

```ruby
pairs = pipeline.compile_pass_one("Your text", document_id: "doc-1")
pairs.each do |clause, ideational|
  puts "#{ideational.process_type}: #{clause.text}"
end
```

### Markdown Document Processing

```ruby
SFL::Compiler::MarkdownLoader.load("path/to/doc.md").each do |section|
  pipeline.compile(section.text, document_id: document_id: section.document_id)
end
```

`MarkdownLoader` chunks by ATX heading, strips YAML frontmatter, renders to HTML then strips tags, normalizes through `PragmaticTokenizer`. Code blocks get dropped — they poison POS parses.

### Retrieval with Scalar Filters

```ruby
retriever = SFL::Compiler::HybridRetriever.new(db: db, embedder: SFL::Compiler::Embedder.new)

results = retriever.retrieve(
  "authentication flow",
  filters: {
    min_modality: 0.7,     # high certainty only
    min_tenor: 0.5,        # semi-formal or formal
    process_type: "material" # action statements, not descriptions
  }
)
```

## The Script

`scripts/parse_metacognitive_coprocessor.rb` runs the NotebookLM sources through the pipeline. Usage:

```bash
bundle exec ruby scripts/parse_metacognitive_coprocessor.rb          # full run
PASS=1 bundle exec ruby scripts/parse_metacognitive_coprocessor.rb   # Pass 1 only
DRY_RUN=1 bundle exec ruby scripts/parse_metacognitive_coprocessor.rb
FILE=specific.md bundle exec ruby scripts/parse_metacognitive_coprocessor.rb
```

## Test Suite

```bash
bundle exec rspec spec/ --format documentation
```

15 examples across 3 spec files: type constraints, ideational classification accuracy, RRF score symmetry.

## Abstraction Leaks

**spaCy via PyCall.** `ruby-spacy` shells out to Python. If the Python env doesn't have `spacy` and `en_core_web_sm` installed, Pass 1 dies. No graceful fallback — it raises `PassOneError`.

**Circuit breaker defaults to a no-op.** `PassTwoEngine#default_circuit_breaker` is `lambda { |&block| block.call }`. The rescue clause catches `CircuitBreaker::CircuitBrokenException` which the no-op lambda never raises. You need to inject a real circuit breaker for production.

**MarkdownLoader depends on Inkmark and PragmaticTokenizer.** Not in theGemfile — the script adds them at runtime. If those gems aren't installed, the md loader won't load.

**Keyword search doesn't join to interpersonal/ideational tables.** The `keyword_search` method queries `clauses` alone. Scalar filtering happens in Ruby after the merge (N+1 query pattern in `apply_filters`). Fine for small result sets, will need a SQL join rewrite at scale.

## File Map

```
lib/sfl/compiler.rb                  # Zeitwerk loader, Configuration, error classes
lib/sfl/compiler/version.rb          # VERSION = "0.1.0"
lib/sfl/compiler/types.rb            # All Dry::Struct types
lib/sfl/compiler/pipeline.rb         # Pipeline — orchestrates both passes
lib/sfl/compiler/pass_one/
  pass_one_engine.rb                 # Spacy::Language.read → SyntacticClause[]
  ideational_extractor.rb            # Rule-based transitivity classification
lib/sfl/compiler/pass_two/
  pass_two_engine.rb                 # DSPy ChainOfThought → InterpersonalPayload
lib/sfl/compiler/storage/
  database.rb                        # Sequel.connect + Migrator (4 tables)
  clause_repository.rb               # Store/find with scalar interpersonal filters
  embedding_repository.rb            # pgvector nearest-neighbors
lib/sfl/compiler/retrieval/
  hybrid_retriever.rb                # RRF merge + scalar filter + Embedder
lib/sfl/compiler/markdown_loader.rb  # ATX-heading chunks → clean prose
lib/sfl-compiler.rb                  # Top-level require
```
