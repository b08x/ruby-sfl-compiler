---
id: "comment_01KWM3TNPSYQHMPHVHGGAQA6BR"
cardId: "card-add-safe-rag-hypothesis-validator-as-a-new-view--0k0sm3a"
createdAt: "2026-07-03T13:48:56.409Z"
updatedAt: "2026-07-03T13:48:56.409Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Follow-up verification complete** — quota headroom confirmed, and it surfaced a real bug along the way.

Re-testing live turned up a second, more serious backend issue: firing the two `POST /synthesize` calls in parallel (as this view does by design) crashed with `NoMethodError: undefined method 'nfields' for nil` / `undefined method '<' for nil` — garbled deep in the pg adapter. Root cause: Sequel's default connection pool keys checked-out connections on `Thread.current`, but Falcon runs concurrent requests as Async fibers *within one thread* — two sibling fibers hit Sequel's re-entrant-hold fast path and got handed the **same** pg connection, interleaving queries on one socket. This wasn't specific to this view; it was a landmine for **any** two concurrent requests hitting the DB through the Falcon API.

Fixed in `Database.connect` (sfl-compiler `f8b971e`): `pool_class: :timed_queue` (checks out by connection identity) + the `fiber_concurrency` extension (makes `Sequel.current` key on `Fiber.current` instead of `Thread.current` — pool_class alone wasn't sufficient, confirmed by reproducing with two bare `Async` tasks sharing one connection before touching pool config at all). Added regression spec + a direct reproduction script confirming two concurrent fibers now get distinct connection objects and correct, non-interleaved results.

With that fixed, the full side-by-side flow now works end-to-end: query "brain network", min_modality 0.40 → both columns show real retrieved evidence with SFL badges (cited clauses highlighted) and two independently synthesized answers with confidence scores, exactly per the acceptance criteria.

773 sfl-compiler examples green (up from 771). Commit: sfl-compiler `f8b971e`.