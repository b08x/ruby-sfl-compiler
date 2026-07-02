---
id: "comment_01KWJ7Q2GGPRQJD5VEFDRSH9ED"
cardId: "card-spike-evaluate-standalone-spacy-service-candidat-18ndr62"
createdAt: "2026-07-02T20:18:23.888Z"
updatedAt: "2026-07-02T20:18:23.888Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Deferred to Phase 3** (2026-07-02). Standalone spaCy service is a scaling concern, not a correctness blocker. PyCall threading issue is fully mitigated by `-c 1` Sidekiq + Gush process-per-turn architecture.