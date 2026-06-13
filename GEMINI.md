# GEMINI.md — SFL Compiler Context

## Project Overview

**SFL Compiler** is a Ruby-based system (v0.1.0 gem) that transforms natural language into structured Systemic Functional Linguistics (SFL) annotations. It is designed to enhance Retrieval-Augmented Generation (RAG) by indexing not just *what* was said (topic), but *how* it was said (rhetorical stance, modality, tenor, and process type).

### Architecture: The Two-Pass Pipeline

The system operates using a strict two-pass architecture to separate deterministic syntactic extraction from probabilistic semantic annotation.

1.  **Pass 1: Syntactic & Ideational Extraction**
    *   **Engine:** `PassOneEngine` (uses `ruby-spacy` via `PyCall` to interop with Python spaCy).
    *   **Tasks:** Tokenization, POS tagging, dependency parsing, sentence segmentation.
    *   **Ideational Extraction:** `IdeationalExtractor` (rule-based Ruby, no LLM). Classifies transitivity (Process Type, Participants, Circumstances) based on syntactic patterns and verb lists.

2.  **Pass 2: Interpersonal & Textual Annotation**
    *   **Engine:** `PassTwoEngine` (uses `DSPy.rb` with an LLM).
    *   **Tasks:** 
        *   **Interpersonal:** Annotates Mood (declarative, interrogative, etc.), Modality Weight (certainty, 0-1), Tenor (formality, 0-1), and Speaker Attitude.
        *   **Textual:** Annotates Theme/Rheme structure (Topical Theme, Textual Theme, Rheme) and Theme Type.
    *   **Resilience:** Batched calls (~12 clauses/call), concurrent processing, and a fallback ladder that marks failed annotations as `annotation_source: "fallback"`.

### Analysis & Insights

The system goes beyond clause-level annotation to provide system-wide insights:
*   **Cohesion Analysis:** `CohesionAnalyzer` calculates Repetition Score, Conjunction Density, and Pronoun Density to measure text flow.
*   **Key Moments:** Detects dramatic shifts in tenor (>0.15) or modality (>0.3) between turns.
*   **Example Passages:** Automatically identifies the "Most Formal," "Most Casual," "Most Certain," and "Most Hedged" passages in the corpus.

### Storage & Retrieval

*   **Database:** PostgreSQL with `pgvector` and `pg_trgm` extensions.
*   **Tables:** `clauses`, `ideational_payloads`, `interpersonal_payloads`, `embeddings`.
*   **Retrieval:** `HybridRetriever` uses Reciprocal Rank Fusion (RRF) to merge semantic (vector) and keyword (full-text) search. It supports **scalar filtering** on stance metadata (e.g., `--min-modality 0.7`).

---

## Building and Running

### Prerequisites

*   **Ruby:** >= 3.3.0
*   **Python:** `pip install spacy && python -m spacy download en_core_web_sm`
*   **PostgreSQL:** Must have `vector` and `pg_trgm` extensions installed.
*   **Environment:** Copy `.env.example` to `.env` and set `DATABASE_URL`, `DSPY_PROVIDER`, and relevant API keys.

### Key Commands

| Task | Command |
| :--- | :--- |
| **Install Dependencies** | `bundle install` |
| **Analyze Conversation** | `bundle exec sfl-analyze conversation <file.jsonl> [--output-dir DIR] [--narrative]` |
| **Analyze Documentation** | `bundle exec sfl-analyze documentation <path> [--store] [--narrative]` |
| **Query Context** | `bundle exec sfl-analyze context "<query>" [--min-modality F] [--limit N]` |
| **Generate Narrative** | `bundle exec sfl-analyze narrate <analysis.json>` |
| **Run Tests** | `bundle exec rspec spec/` (Use `bin/rspec` if binstub fails) |
| **Lint Code** | `bundle exec rubocop` |

Default output directory is `./output/latest`.
### Documentation Index

*   **Guides:** `docs/guides/QUICKSTART.md`, `docs/guides/USAGE.md`
*   **Planning:** `docs/planning/NOTEBOOK_ANALYSIS_PLAN.md`, `docs/planning/RESEARCH_APPLICATION_PLAN.md`, `docs/superpowers/plans/`
*   **Status:** `docs/status/BACKLOG_FIXES.md`, `docs/status/KNOWN_ISSUES.md`, `docs/status/SESSION_SUMMARY.md`, `docs/status/DEBUGGING_SESSION.md`
*   **Architecture & Theory:** `docs/geb-lens-on-sfl-compiler.md`, `docs/knowledge-base.md`, `docs/poignant-guide-to-sfl-compiler.md`
*   **Articles:** `docs/articles/from-graph-to-story.md`

---

## Instructional Mental Models

When operating on this codebase, apply these theoretical lenses derived from project documentation:

### 1. The "Clothes" Metaphor (Interpersonal Stance)
*   **Concept:** Most RAG systems index the "naked topic-meat." SFL Compiler indexes the **clothes**—the rhetorical stance.
*   **Application:** `tenor` is the tuxedo vs. pajamas (formality); `modality` is the stride vs. shuffle (certainty). Always maintain the separation between what is said (Ideational) and how it is worn (Interpersonal).

### 2. The "pq-System" (Pass 1 Determinism)
*   **Concept:** Pass 1 is a formal typographical system. It doesn't "understand" meaning; it maps syntactic symbols (dependency labels) to SFL roles via isomorphic rules.
*   **Application:** Trust Pass 1 for structural consistency. If a transitivity classification is wrong, the derivation rule in `IdeationalExtractor` is misaligned with the linguistic domain.

### 3. The "Decoder Key" (Provenance)
*   **Concept:** Data without provenance is ambiguous. A `tenor` of 0.5 can be a measurement (mixed formality) or a failure (placeholder).
*   **Application:** Always check `annotation_source`. `llm` is data; `fallback` is a signal of system ignorance. Never treat a fallback as a finding.

### 4. The "Strange Loop" (Self-Reference)
*   **Concept:** The system is capable of analyzing its own code and documentation.
*   **Application:** When the system analyzes itself, ensure the "meta-level" (description) and "object-level" (code) are clearly distinguished in reports.

---

## Development Conventions
*   **Strict Layering:**
    *   **CLI (`lib/sfl/compiler/cli.rb`):** Owns argument parsing, terminal I/O, and exit codes.
    *   **Bootstrap (`lib/sfl/compiler/bootstrap.rb`):** The ONLY component allowed to read environment variables (`ENV`). Wires configuration and connects DB/LLM.
    *   **Analyzers:** Must be UI-agnostic. No `puts`, `exit`, or `ENV` access. Use the injectable `on_progress` callback for progress reporting.
*   **Type Safety:** Uses `Dry::Struct` and `Dry::Types` (see `lib/sfl/compiler/types.rb`) for all internal data structures and SFL payloads.
*   **Autoloading:** Managed by `Zeitwerk`. Note that `analysis/` and `formatters/` directories are collapsed and require explicit entries in their respective manifest files (`lib/sfl/compiler/analysis.rb`, `lib/sfl/compiler/formatters.rb`).
*   **Error Handling:** Custom errors inherit from `SFL::Compiler::Error`.

### Testing Practices

*   **Framework:** RSpec.
*   **Configuration:** Random execution order enabled. Use `fit` or `fdescribe` for focused testing.
*   **Unit Tests:** Preferred. Avoid DB/LLM dependencies in unit specs by mocking or using `PASS=1` logic.
*   **Integration Tests:** `spec/integration/` is currently known to be brittle; focus on unit tests for core logic.

### Gotchas

*   **Python Interop:** `ruby-spacy` requires a valid Python environment. If Pass 1 fails, ensure `spacy` and the `en_core_web_sm` model are available.
*   **GC & PyCall:** The pipeline manually triggers `GC.start` between Pass 1 and Pass 2 to prevent deadlocks between the Ruby GVL and Python GIL during garbage collection of PyCall pointers.
*   **Zeitwerk Manifests:** If you add a new file to `lib/sfl/compiler/analysis/` or `lib/sfl/compiler/formatters/`, you **MUST** add a `require_relative` line in the parent directory's manifest file.
