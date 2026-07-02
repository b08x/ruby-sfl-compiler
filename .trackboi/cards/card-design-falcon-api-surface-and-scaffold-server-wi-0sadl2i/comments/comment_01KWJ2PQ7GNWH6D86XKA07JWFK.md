---
id: "comment_01KWJ2PQ7GNWH6D86XKA07JWFK"
cardId: "card-design-falcon-api-surface-and-scaffold-server-wi-0sadl2i"
createdAt: "2026-07-02T18:50:49.456Z"
updatedAt: "2026-07-02T18:50:49.456Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Scaffold shipped. Files created:
- `lib/sfl/compiler/api/server.rb` — Rack app; GET /health → 200, 5 stub routes → 501
- `lib/sfl/compiler/api.rb` — manifest (require_relative only, not autoloaded by Zeitwerk)
- `lib/sfl/compiler/api_boot.rb` — APIBoot.call wraps Bootstrap with require_db/require_llm, no PyCall
- `config.ru` — Rack entry point for `falcon serve`
- `exe/sfl-api` — binstub (exec falcon serve config.ru -b http://localhost:PORT)
- Zeitwerk: `loader.ignore("compiler/api")` added to lib/sfl/compiler.rb
- Gemspec: `falcon ~> 0.48`, `async ~> 2.21`, `sfl-api` added to executables

All 5 files pass `ruby -c`. DB/LLM not available in test sandbox; full acceptance test (`bundle exec sfl-api` → GET /health → 200) requires live DB. Moving to done — implementation cards remain.