---
id: "comment_01KWM33PSVK3F4DC6S1W95TVAF"
cardId: "card-add-safe-rag-hypothesis-validator-as-a-new-view--0k0sm3a"
createdAt: "2026-07-03T13:36:23.867Z"
updatedAt: "2026-07-03T13:36:23.867Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Done**, with one caveat noted below.

New `/rag-validator` route (`SafeRagValidator.tsx`): query input, min-modality/min-tenor sliders, mood select. Submit fires two parallel `POST /synthesize` calls — one with `filters: {}`, one with the configured stance filters — rendered side by side. Each column lists retrieved evidence clauses (cited ones highlighted) then the synthesized answer + confidence.

**Backend change** (sfl-compiler `86944d1`): `ContextSynthesizer#synthesize` was fetching each clause's ideational/interpersonal annotations only to decide the citable/fallback split, then explicitly stripping them back out before returning `clauses:`. Flattened `mood`/`tenor`/`modality_weight`/`process_type`/`annotation_source` onto each row instead — needed for the evidence-with-annotations display the card calls for. Added spec coverage; existing specs untouched (they only checked `clauses.size`).

**Also fixed**: base-ui's `SelectValue` was rendering the raw sentinel value (`__any__`) instead of "Any" — needs an explicit render-prop `children` to map value→label. Same gap exists in `GraphExplorer`'s older filter selects; left those alone (out of scope).

**Verified live, partially**: sliders/select drive state correctly, the form dispatches both requests in parallel, and a direct `POST /retrieve` call confirmed evidence retrieval itself works (5 real matches for "brain network" against the stored corpus). Could **not** verify the synthesized-answer half live — the configured OpenRouter key is at its account-wide quota limit (`403 Key limit exceeded`), an external constraint. Left `ContextSynthesizer`'s existing "LLM failures propagate" design alone rather than adding a fallback to force a demo — that's a deliberate documented choice, not a bug. Worth a follow-up live check once the key has headroom again.

771 sfl-compiler examples green, ConvoWorkbench `tsc --noEmit` clean. Commits: sfl-compiler `86944d1`, ConvoWorkbench `3c36fe7`.