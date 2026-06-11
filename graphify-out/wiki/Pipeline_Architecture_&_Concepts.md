# Pipeline Architecture & Concepts

> 12 nodes · cohesion 0.21

## Key Concepts

- **PassTwoEngine** (9 connections) — `lib/sfl/compiler/pass_two/pass_two_engine.rb`
- **PassOneEngine** (6 connections) — `lib/sfl/compiler/pass_one/pass_one_engine.rb`
- **IdeationalExtractor** (5 connections) — `lib/sfl/compiler/pass_one/ideational_extractor.rb`
- **pipeline.rb** (4 connections) — `lib/sfl/compiler/pipeline.rb`
- **Two-Pass Architecture** (2 connections) — `docs/knowledge-base.md`
- **Circuit Breaker Pattern** (1 connections) — `docs/knowledge-base.md`
- **DSPy ChainOfThought** (1 connections) — `docs/knowledge-base.md`
- **Lemma-Based Classification** (1 connections) — `docs/knowledge-base.md`
- **ruby-spacy via PyCall** (1 connections) — `docs/knowledge-base.md`
- **SFL Metafunctions** (1 connections) — `docs/knowledge-base.md`
- **SFLSignature (typed DSPy signature)** (1 connections) — `docs/knowledge-base.md`
- **MarkdownLoader** (1 connections) — `lib/sfl/compiler/markdown_loader.rb`

## Relationships

- [[Type System & Storage]] (4 shared connections)
- [[Pipeline Compilation Flow]] (1 shared connections)

## Source Files

- `docs/knowledge-base.md`
- `lib/sfl/compiler/markdown_loader.rb`
- `lib/sfl/compiler/pass_one/ideational_extractor.rb`
- `lib/sfl/compiler/pass_one/pass_one_engine.rb`
- `lib/sfl/compiler/pass_two/pass_two_engine.rb`
- `lib/sfl/compiler/pipeline.rb`

## Audit Trail

- EXTRACTED: 27 (82%)
- INFERRED: 6 (18%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*