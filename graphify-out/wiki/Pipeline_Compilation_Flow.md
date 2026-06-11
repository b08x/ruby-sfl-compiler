# Pipeline Compilation Flow

> 11 nodes · cohesion 0.25

## Key Concepts

- **Pipeline** (5 connections) — `lib/sfl/compiler/pipeline.rb`
- **.compile()** (5 connections) — `lib/sfl/compiler/pipeline.rb`
- **PassOneEngine** (5 connections) — `lib/sfl/compiler/pass_one/pass_one_engine.rb`
- **.process()** (5 connections) — `lib/sfl/compiler/pass_one/pass_one_engine.rb`
- **.annotate()** (4 connections) — `lib/sfl/compiler/pass_two/pass_two_engine.rb`
- **.compile_pass_one()** (3 connections) — `lib/sfl/compiler/pipeline.rb`
- **.compile_pass_two()** (2 connections) — `lib/sfl/compiler/pipeline.rb`
- **.extract_tokens_from_span()** (2 connections) — `lib/sfl/compiler/pass_one/pass_one_engine.rb`
- **.find_root_index()** (2 connections) — `lib/sfl/compiler/pass_one/pass_one_engine.rb`
- **.initialize()** (1 connections) — `lib/sfl/compiler/pipeline.rb`
- **pass_one_engine.rb** (1 connections) — `lib/sfl/compiler/pass_one/pass_one_engine.rb`

## Relationships

- [[Ideational Extraction]] (2 shared connections)
- [[Pass Two Engine]] (2 shared connections)
- [[Pipeline Architecture & Concepts]] (1 shared connections)
- [[Hybrid Retrieval System]] (1 shared connections)
- [[Core Compiler Configuration]] (1 shared connections)

## Source Files

- `lib/sfl/compiler/pass_one/pass_one_engine.rb`
- `lib/sfl/compiler/pass_two/pass_two_engine.rb`
- `lib/sfl/compiler/pipeline.rb`

## Audit Trail

- EXTRACTED: 24 (69%)
- INFERRED: 11 (31%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*