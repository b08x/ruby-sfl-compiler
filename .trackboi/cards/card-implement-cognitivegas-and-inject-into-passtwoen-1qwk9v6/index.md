---
id: "card-implement-cognitivegas-and-inject-into-passtwoen-1qwk9v6"
boardId: "default"
title: "Implement CognitiveGas and inject into PassTwoEngine circuit breaker slot"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-cognitive-gas-semantic-circuit-breaker-0xefy41"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:24.559Z"
updatedAt: "2026-07-02T19:48:14.843Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
New `lib/sfl/compiler/cognitive_gas.rb`. Replace `PassTwoEngine#default_circuit_breaker` no-op lambda with a real `CognitiveGas` instance. The `circuit_breaker.call { block }` interface already exists in `PassTwoEngine` — inject via constructor (`circuit_breaker:` keyword arg, defaulting to `CognitiveGas.new`). `CognitiveGas#call` tracks cumulative cost, raises `CircuitBreaker::CircuitBrokenException` when budget exhausted. Acceptance: 0 test regressions; new spec verifies budget exhaustion raises the exception; `PassTwoEngine` spec verifies the rescue clause now actually fires.