# PassOneEngine

**Location:** `lib/sfl/compiler/pass_one/pass_one_engine.rb`
**Confidence:** EXTRACTED

---

## Transformation Contract

```
Raw Text → [PassOneEngine.process] → Array<SyntacticClause>
```

| Input | Output | Condition |
|-------|--------|-----------|
| String (section text) | `Array<Types::SyntacticClause>` | text non-empty |
| nil / empty string | `[]` | early return |

---

## Responsibilities

- Tokenize text via spaCy NLP pipeline
- Extract sentence boundaries from dependency parse
- Build `SyntacticToken` structs with POS, dependency, morphology
- Identify ROOT token index per sentence
- Log timing and correlation IDs via Journald

---

## Key Components

| Component | Role |
|-----------|------|
| `initialize(model:)` | Load spaCy language model (default from config) |
| `process(text, document_id:)` | Main entry: text → array of syntactic clauses |
| `extract_tokens_from_span(sent)` | Convert spaCy sentence span to `SyntacticToken` array |
| `find_root_index(tokens)` | Locate ROOT dependency in token list |

---

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `ruby-spacy` | spaCy NLP bridge via PyCall |
| `SFL::Compiler.config.spacy_model` | Default model name |
| `Types::SyntacticClause` | Output struct |
| `Types::SyntacticToken` | Token-level struct |
| `Journald::Logger` | Structured logging |

---

## Interactions

```mermaid
graph LR
    A[Raw Text] --> B[PassOneEngine]
    B --> C[spaCy NLP]
    C --> D[SyntacticClause[]]
    D --> E[IdeationalExtractor]
    D --> F[Pipeline]
```

---

## User/Developer Experience

**Developer** calls `PassOneEngine.new.process(text)` and receives an array of `SyntacticClause` structs, each containing:
- `id` — UUID
- `text` — sentence text
- `tokens` — array of `SyntacticToken`
- `root_index` — index of ROOT dependency
- `sentence_index` — position in document
- `document_id` — optional source identifier

**User** never interacts directly; the engine is called by `Pipeline.compile` or `ConversationAnalyzer`.

---

## Known Limitations

1. **PyCall/GIL constraint** — spaCy runs in a single Python interpreter; multi-threaded use deadlocks
2. **Model dependency** — requires spaCy model installed (`en_core_web_sm` etc.)
3. **Sentence segmentation** — relies on spaCy's dependency-based sentencizer, not rule-based

---

## Design Rationale

The engine performs a single `@nlp.read(text)` call per section, letting spaCy handle sentence segmentation as a by-product of dependency parsing. Token indices are sentence-local (0-based), matching the `root_index` stored on `SyntacticClause`.

---

## Ruby Pragmatist Insight

> PassOneEngine is a **translator** — it converts raw human language into a structured grammatical representation. Like a linguist parsing a sentence diagram, it identifies the ROOT, maps dependencies, and extracts morphological features. The result is not meaning (that's Pass 2's job), but structure — the skeleton upon which meaning is hung.

---

## Trace Path

```
pipeline.rb:47  Pipeline.compile
  └─► pass_one_engine.rb:33  PassOneEngine.process
       ├─► pass_one_engine.rb:73  extract_tokens_from_span
       └─► pass_one_engine.rb:103 find_root_index
```
