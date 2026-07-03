# Database

**Location:** `lib/sfl/compiler/storage/database.rb`
**Confidence:** EXTRACTED

---

## Transformation Contract

```
DATABASE_URL → [Database.connect] → Sequel::Database (fiber-safe connection pool)
```

| Input | Output | Condition |
|-------|--------|-----------|
| `url` (String, optional) | Connected `Sequel::Database` with `pg_json` extension loaded | falls back to `SFL::Compiler.config.database_url` if `url` is nil |

---

## Responsibilities

- Open the single `Sequel::Database` connection every repository (`ClauseRepository`, `EmbeddingRepository`, `AxiomaticSummaryRepository`, `PipelineCache`'s DB-backed callers, etc.) shares
- Select a connection pool implementation safe under both threaded (Sidekiq) and fiber-based (Falcon/Async) concurrency
- Create the `vector` (pgvector) and `pg_trgm` Postgres extensions
- Run `Migrator.run_all` to create/verify all tables and indices

---

## Key Components

| Component | Role |
|-----------|------|
| `Database.connect(url = nil)` | Opens the pooled connection; loads `pg_json` |
| `Database.setup_extensions(db)` | `CREATE EXTENSION IF NOT EXISTS vector` / `pg_trgm` |
| `Migrator.run_all` | Idempotent `create_table?` calls for every table + index |

---

## Dependencies

| Dependency | Purpose |
|------------|---------|
| `sequel` | Connection pooling, query building, migrations |
| `sequel/extensions/fiber_concurrency` | Makes `Sequel.current` key on `Fiber.current` instead of `Thread.current` |
| `pgvector` | Vector column type support |
| `pg` (native) | Postgres driver |

---

## Known Limitations / Design Rationale

**`pool_class: :timed_queue` + the `fiber_concurrency` extension are both required, and neither alone is sufficient.** Falcon runs concurrent HTTP requests as Async fibers within a single OS thread. Sequel's default connection pool checks out connections keyed on `Sequel.current`, which is `Thread.current` by default — so without `fiber_concurrency`, two sibling fibers on the same thread hit the pool's re-entrant-hold fast path (`Pool#hold` treats a second caller with the same key as a *nested* call, not a *concurrent* one) and get handed the **same** pg connection, even with a fiber-capable pool class selected. Their queries then interleave on one socket, surfacing as garbled `NoMethodError`s deep in the pg adapter (`undefined method 'nfields' for nil`, `undefined method '<' for nil`) with no useful stack trace context at the API layer.

This was found live: the ConvoWorkbench Safe RAG Hypothesis Validator view fires two concurrent `POST /synthesize` calls by design (unfiltered vs. stance-filtered), which reliably reproduced the corruption before this fix. `TimedQueueConnectionPool` (Ruby 3.2+, `sequel/connection_pool/timed_queue.rb`) checks connections out by object identity rather than thread, and is safe once `Sequel.current` actually varies per fiber.

This affects every concurrent request pair through the Falcon API, not just `/synthesize` — any two simultaneous requests hitting the database were at risk of exactly this corruption before the fix.

## Ruby Pragmatist Insight

> A connection pool's safety guarantee is only as good as the key it uses to tell callers apart. `Thread.current` was the right key when every concurrent caller had its own OS thread; under Falcon's fiber-based reactor, many callers share one thread, and a key that can't tell them apart hands out the same resource to two callers who each think they have it exclusively — the pool wasn't broken, its assumption about what "the same caller" means was.

---

## Trace Path

```
bootstrap.rb   Bootstrap.call(require_db: true)
  └─► database.rb:27   Database.connect
       ├─► database.rb (Sequel.extension :fiber_concurrency, module-level, loaded once)
       └─► Sequel.connect(url, pool_class: :timed_queue)
```
