# Core Compiler Configuration

> 24 nodes · cohesion 0.09

## Key Concepts

- **compiler.rb** (8 connections) — `lib/sfl/compiler.rb`
- **Migrator** (8 connections) — `lib/sfl/compiler/storage/database.rb`
- **config()** (4 connections) — `lib/sfl/compiler.rb`
- **Configuration** (3 connections) — `lib/sfl/compiler.rb`
- **logger()** (3 connections) — `lib/sfl/compiler.rb`
- **database.rb** (3 connections) — `lib/sfl/compiler/storage/database.rb`
- **.initialize()** (2 connections) — `lib/sfl/compiler/pass_one/pass_one_engine.rb`
- **.initialize()** (2 connections) — `lib/sfl/compiler/pass_two/pass_two_engine.rb`
- **connect()** (2 connections) — `lib/sfl/compiler/storage/database.rb`
- **setup_extensions()** (2 connections) — `lib/sfl/compiler/storage/database.rb`
- **.initialize()** (1 connections) — `lib/sfl/compiler.rb`
- **.validate!()** (1 connections) — `lib/sfl/compiler.rb`
- **ConfigurationError** (1 connections) — `lib/sfl/compiler.rb`
- **configure()** (1 connections) — `lib/sfl/compiler.rb`
- **Error** (1 connections) — `lib/sfl/compiler.rb`
- **PassOneError** (1 connections) — `lib/sfl/compiler.rb`
- **PassTwoError** (1 connections) — `lib/sfl/compiler.rb`
- **.create_clauses_table()** (1 connections) — `lib/sfl/compiler/storage/database.rb`
- **.create_embeddings_table()** (1 connections) — `lib/sfl/compiler/storage/database.rb`
- **.create_ideational_table()** (1 connections) — `lib/sfl/compiler/storage/database.rb`
- **.create_indices()** (1 connections) — `lib/sfl/compiler/storage/database.rb`
- **.create_interpersonal_table()** (1 connections) — `lib/sfl/compiler/storage/database.rb`
- **.initialize()** (1 connections) — `lib/sfl/compiler/storage/database.rb`
- **.run_all()** (1 connections) — `lib/sfl/compiler/storage/database.rb`

## Relationships

- [[Pass Two Engine]] (2 shared connections)
- [[Pipeline Compilation Flow]] (1 shared connections)

## Source Files

- `lib/sfl/compiler.rb`
- `lib/sfl/compiler/pass_one/pass_one_engine.rb`
- `lib/sfl/compiler/pass_two/pass_two_engine.rb`
- `lib/sfl/compiler/storage/database.rb`

## Audit Trail

- EXTRACTED: 42 (82%)
- INFERRED: 9 (18%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*