---
id: "card-investigate-dspy-openrouter-llm-calls-hang-indef-0kj0scl"
boardId: "default"
title: "Investigate: DSPy/OpenRouter LLM calls hang indefinitely past all configured Pass 2 timeouts"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-rolling-synthesis-fractal-graphs-0bhnviv"
column: "backlog"
rank: "yyy"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-07-03T15:35:14.943Z"
updatedAt: "2026-07-03T15:35:14.943Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Confirmed live (2026-07-03) during Rolling Synthesis validation (`experiments/RESULTS.md` "Bug 2"). Two separate full-document `PassTwoEngine#annotate_batch` runs (one at `concurrency: 4`, one at `concurrency: 1`) stalled indefinitely — 630s+ with zero forward progress despite `chunk_timeout` (120s) × `batch_attempts` (3) = ~360s worst-case per chunk.

`ss -tnp` on the stuck process showed sockets to OpenRouter's Cloudflare front (`104.18.2.115:443`, `104.18.3.115:443`) sitting in `CLOSE-WAIT`/`ESTABLISHED` with large **unread** `Recv-Q` backlogs (up to 15,901 bytes) — response bytes sitting in the kernel buffer, never read by the process. This is exactly the failure class `pass_two_engine.rb`'s own `DEFAULT_CHUNK_TIMEOUT` comment already anticipated ("response bytes sitting unread in the socket while the async reactor deadlocks on a mutex"), but the existing `Timeout.timeout` wrapper (`chunk_timeout`) did not actually recover it in either run — both sat stuck for 10+ minutes, well past every configured layer.

**Workaround used** (not a fix): isolate each unit of Pass 2 work in its own OS process via `timeout 60 bundle exec ruby ...`, so a hang can be killed from outside without losing prior progress (`experiments/process_one_pdf_section.rb`, `experiments/compress_one_window.rb`). Only 26 of 59 sections (44%) completed within a 60s-per-process budget on the affected run — this is a *high* hang rate, not a rare edge case.

**Impact**: standing reliability risk for any long-running Pass 2 call — `sfl-analyze documentation`/`conversation` CLI subcommands, and the Gush-based `CompileTurnJob`/`CompileSectionJob` workflows (which already run one-job-per-turn/section in separate Sidekiq processes, so they're naturally isolated from this — but a single job whose own LLM call hangs would still block that job indefinitely with no external recovery).

**Suggested investigation**: this smells like a known Ruby class of bug — `Timeout.timeout` doesn't reliably interrupt a blocking native read (e.g. inside a C extension or a read that doesn't check for pending interrupts) — rather than something fixable by tuning the timeout *value*. Check what HTTP client DSPy::LM/Faraday uses under the hood and whether it supports a lower-level socket read timeout (`read_timeout`) instead of relying on an application-level `Timeout.timeout` wrapper around the whole call.

**Acceptance**: a repro that reliably triggers the hang (or documents why it's nondeterministic/provider-side), and either (a) a fix that makes the existing timeout actually recover, or (b) a documented decision to keep using OS-process-level isolation as the real mitigation (matching the existing PyCall/spaCy precedent, CLAUDE.md gotcha #12) with that pattern adopted somewhere real rather than left in a throwaway experiment script.