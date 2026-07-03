---
id: "card-fix-bootstrap-bootstraperror-constant-resolution-12g5zfy"
boardId: "default"
title: "Fix Bootstrap::BootstrapError constant resolution bug in provider_fallback.rb"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: null
column: "backlog"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T06:55:03.480Z"
updatedAt: "2026-07-03T06:55:03.480Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Found incidentally while verifying the source_type provenance card (2026-07-03). `lib/sfl/compiler/pass_two/provider_fallback.rb` line ~42 rescues `Bootstrap::BootstrapError`, but the real constant is `SFL::Compiler::BootstrapError` (top-level, not nested under `Bootstrap`). This raises `NameError: uninitialized constant SFL::Compiler::Bootstrap::BootstrapError` intermittently in `spec/sfl/compiler/pass_two/circuit_breaker_spec.rb`, depending on RSpec's random seed / test execution order — a classic Zeitwerk + Ruby constant-lookup timing issue (whether `Bootstrap::BootstrapError` resolves via nesting or falls through to lexical scope depends on what's already loaded). Confirmed pre-existing: reproduces against commit c7c2be9 (before the source_type card's changes) with `--seed 7633` or `--seed 2`; passes reliably with `--seed 1`.

Fix: change the rescue clause to `SFL::Compiler::BootstrapError` (or just `BootstrapError` if lexical scope resolves correctly from that file's nesting — verify). Acceptance: `bundle exec rspec spec/sfl/compiler/pass_two/circuit_breaker_spec.rb --seed 7633` and `--seed 2` both pass.