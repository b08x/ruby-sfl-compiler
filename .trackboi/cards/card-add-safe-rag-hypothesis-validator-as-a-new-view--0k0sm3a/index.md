---
id: "card-add-safe-rag-hypothesis-validator-as-a-new-view--0k0sm3a"
boardId: "default"
title: "Add Safe RAG Hypothesis Validator as a new view in the adapted shell"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-react-frontend-google-ai-studio-024lr42"
column: "done"
rank: "yyj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T05:41:56.352Z"
updatedAt: "2026-07-03T13:48:56.409Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Depends on the GraphContext/Falcon wiring card. The track's original primary view, unaffected by the ConvoWorkbench pivot except in delivery mechanism: a new route/view inside the adopted shell (not a from-scratch app). Side-by-side comparison: same query, same corpus, WITHOUT stance filters vs. WITH configurable stance filters (modality slider, tenor slider, mood selector — `Slider`/`Select` components already exist in ConvoWorkbench's UI kit). Each column shows filtered evidence clauses with SFL annotations, then the LLM-generated answer. Consumes `POST /retrieve` and `POST /synthesize` from the Falcon API. Acceptance: adjust `min_modality` slider from 0 to 1, hit Submit, see different evidence sets and answers in each column.