---
id: "comment_01KWK98TRJSS9R1A5TJFWE8EEH"
cardId: "card-strip-convoworkbench-s-client-side-data-llm-laye-0ecj1yh"
createdAt: "2026-07-03T06:04:48.786Z"
updatedAt: "2026-07-03T06:04:48.786Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
**Substantially complete, verified end-to-end live (not just tsc/build).**

**Removed** (browser LLM calls / API keys / duplicate-of-server-logic): `graph/builder.ts`, `graph/topic_extraction.ts`, `providers/{gemini,groq,mistral,ollama,openrouter}.ts`, `distillation/orchestrator.ts`, `trajectory/compiler.ts`. Kept `graph/embeddings.ts`/`graph/query.ts` — pure TF-IDF/cosine math and a local-state GraphQL executor, no LLM/API-key involvement, so removing them wasn't actually required by the card's stated risk (deviation from the literal card text, noted here for the record).

**Added**: `src/types/sfl.ts` (mirrors Ruby `Types::AnnotatedClause` etc.), `src/lib/api/sflClient.ts` (typed fetch wrapper for `/health /retrieve /synthesize /pipeline/compile /workflows`), `src/vite-env.d.ts`. `GraphContext` gained a real `fetchFromCorpus()` calling `sflClient.retrieve` and merging results into state — rating/notes stayed as legitimate local UI state (not LLM logic, not duplicated server logic).

**Rewired**: `ImportWizard` → corpus search box (was file-upload + client parsing). `ConversationViewer`'s "Search & Retrieve" → real `/retrieve` call (was direct Gemini call); "Summarize" → honest "not available" message (no general-purpose LLM endpoint exists server-side to redirect to — using `/synthesize` here would've been silently wrong, since it answers a *query* from retrieved evidence, not "summarize this given text"). `ProviderContext` stripped of adapters, kept as pure task-config state for the Model Provider Configuration track's future consumption. `SkillDistiller`/`TrajectoryCompiler`/`Graph3D` per-node summary+TTS/`GraphInsights` → "not yet available over the API" placeholders (their server-side equivalents — SprintWorkflow, IntermediateGenieJob — aren't exposed via Falcon yet).

**Server-side addition** (not in the original card, but required to make any of this reachable from a browser): hand-rolled CORS on `api/server.rb` (dev-only origin allowlist, no new gem dependency) — 4 new specs, 21/21 passing.

**Real bug found and fixed via live testing**: assumed `/retrieve` returned full `AnnotatedClause` (mood/tenor/process_type). It actually returns `HybridRetriever`'s thin row (`clause_id`, `text`, `document_id`, rank scores) — `apply_filters` queries the SFL payload server-side to decide inclusion but never merges it back into the response, even when filters narrow the result set. This crashed `ConversationViewer`'s search action in the browser (`Cannot read properties of undefined (reading 'process_type')`). Fixed by introducing `RetrievedClauseSummary` as its own type distinct from `AnnotatedClause`, correcting `GraphContext`'s mapping (`clause_id` not `id`, no `compiled_at`), and rewriting the search formatter to only use fields that actually exist. **Flagging for the Corpus Browser card**: if per-clause SFL annotation display is wanted from `/retrieve` results, either the endpoint needs to start returning ideational/interpersonal payloads, or the browser needs a second call (`/synthesize` or a future `/clauses` endpoint) to fetch them — this was verified against the real endpoint, not assumed.

**Verification**: `tsc --noEmit` clean. Live smoke test: `npm run dev` + `bundle exec falcon serve` + real Postgres, seeded one clause via `/pipeline/compile store:true`, drove the browser through Import → search → Review → clause detail → Search & Retrieve, confirmed zero console errors post-fix. Ruby suite 700/700, rubocop clean on new/touched code (pre-existing Metrics offenses on untouched methods left as-is).

**Deferred / not done**: `ExportPanel` still spreads `loading`/`error` fields into its exported `graph.json` (cosmetic, not functional). No `GET /models` endpoint yet, so Settings' provider/model pickers render empty (expected — tracked on Model Provider Configuration).