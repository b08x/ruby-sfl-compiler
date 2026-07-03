---
id: "card-per-domain-json-report-keys-topicmodeler-dominan-19thonv"
boardId: "default"
title: "Per-domain JSON report keys + TopicModeler dominance gate"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: null
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T04:45:43.816Z"
updatedAt: "2026-07-03T04:45:43.816Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Retroactive card — shipped in c7ab6b3. Two related fixes from the /goal-2 unstructured-vault-text workstream (no single owning track; touches documentation analysis + topic modeling):

1. **JSON schema no longer mislabels sections as speakers**: documentation-domain reports rename `speaker_profiles`→section-appropriate keys via `JSONFormatter.id_key_for/profiles_key_for/...(metadata)`; `Digest.canonicalize_metadata` translates back order-preservingly so the from_result/from_json text-equivalence contract holds. Speaker profiles are now reserved for `conversation` analysis.

2. **TopicModeler dominant-topic gate**: normalized excess-over-uniform confidence `(p1 − 1/k)/(1 − 1/k)`, k-independent, `DEFAULT_DOMINANT_THRESHOLD = 0.35`. Same gate serves "what is this turn/text/document about". Empty tokens → `dominant_topic: nil` (was fiat topic 0); topic-shift detection skips nil-dominant turns. Validation on sillytavern corpus: 191 spurious topic shifts → 5.