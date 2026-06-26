# Decisions

## [accepted] Rebuild --live on Gush workflow instead of patching BatchApp's threading

Considered: (a) keep BatchApp's architecture and try to make PyCall safe across threads (e.g. a mutex/single-PyCall-thread queue), (b) replace it with the Gush/Sidekiq workflow's process-level parallelism. Chose (b): PyCall's own docs say multi-threaded use isn't supported at all, so any in-process-thread fix would be fighting upstream rather than working with it. The Gush workflow already exists, is tested, and gives process isolation for free. The TUI becomes a thin Redis/Postgres-polling client — it never touches PyCall directly.
