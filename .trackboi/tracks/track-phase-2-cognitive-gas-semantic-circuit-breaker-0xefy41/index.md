---
id: "track-phase-2-cognitive-gas-semantic-circuit-breaker-0xefy41"
title: "Phase 2 — Cognitive Gas (Semantic Circuit Breaker)"
slug: "phase-2-cognitive-gas-semantic-circuit-breaker"
createdAt: "2026-06-26T04:11:27.257Z"
updatedAt: "2026-06-26T04:11:27.257Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Replaces the no-op `lambda { |&block| block.call }` circuit breaker in `PassTwoEngine` with a semantically-weighted budget model. Each clause consumed by a reasoning agent costs "gas" proportional to its SFL-derived cognitive weight (process complexity + modality density + tenor shift). Budget exhaustion triggers graceful Rolling Synthesis rather than a BIGINT database crash. See ROADMAP.md §2.