# Decisions

## [accepted] Defer standalone spaCy service to Phase 3

Deferred 2026-07-02. The PyCall segfault at concurrency > 1 is fully mitigated by `-c 1` Sidekiq constraint and the Gush process-per-turn architecture. Extracting spaCy into a separate HTTP/gRPC microservice is a scaling concern, not a correctness blocker. Spike + implementation deferred to Phase 3 alongside React/Falcon frontend work.
