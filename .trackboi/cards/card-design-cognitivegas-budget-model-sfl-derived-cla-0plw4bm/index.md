---
id: "card-design-cognitivegas-budget-model-sfl-derived-cla-0plw4bm"
boardId: "default"
title: "Design CognitiveGas budget model: SFL-derived clause cost weights"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-cognitive-gas-semantic-circuit-breaker-0xefy41"
column: "backlog"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:19.739Z"
updatedAt: "2026-06-26T04:13:19.739Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Design work. Define: (1) cost function — process_type weight table (material/mental > relational/existential), modality_weight multiplier, tenor-shift delta vs. running average; (2) budget unit (abstract "gas" units, not tokens); (3) default budget per reasoning loop and env-override (`COGNITIVE_GAS_BUDGET`); (4) exhaustion callback interface (how it triggers Rolling Synthesis or graceful halt); (5) how cost is tracked across a Gush workflow (job-level params vs. Redis counter). Acceptance: ADR + `CognitiveGas` class interface spec (TDD shell, no implementation yet).