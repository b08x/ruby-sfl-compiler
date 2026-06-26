---
id: "comment_01KVY9BR9YS47X3F6TJGDCHBHQ"
cardId: "card-crabconstraintjob-rule-based-invariant-pinning-n-1mqtw2i"
createdAt: "2026-06-25T02:22:21.502Z"
updatedAt: "2026-06-25T02:22:21.502Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Implemented in `lib/sfl/compiler/jobs/crab_constraint_job.rb` (commit 4373d61), with a deliberate deviation from the card's draft design: **invariants are JSON-safe data (`{name:, field:, op:, value:}`), not `check: ->(claim) {...}` Procs.** Caught before writing the spec by reading `Gush::Job#to_json` (→ `Gush::JSON.encode(as_json)`) — `params` gets serialized to Redis whenever a job is enqueued for a real Sidekiq worker process, and a Ruby Proc cannot survive that round trip. A small fixed `OPERATORS` registry (`eq/neq/gt/gte/lt/lte/present/absent`) is the serializable equivalent: domain tracks supply data describing a check, the job supplies the code that runs it.

4 specs including the acceptance criterion (documentation track's fallback-exclusion + min-clause-threshold invariants correctly partitioning a 3-claim fixture). Full suite: 335 examples, 0 failures. `SprintWorkflow` (the last shared-substrate card) is next, and its `domain_payload`/invariants contract needs to match this data shape, not the Proc shape originally sketched in that card's own description.