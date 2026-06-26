---
id: "comment_01KVYNABGYEGE6D4QZBT402T9X"
cardId: "card-langfuse-opentelemtry-connection-error-handling-146vxof"
createdAt: "2026-06-25T05:51:18.558Z"
updatedAt: "2026-06-25T05:51:18.558Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Done — commit 8a594c0.

**Root cause**: the reported error is OTel's OTLP exporter repeatedly failing to flush spans to an unreachable `LANGFUSE_HOST` — not a pipeline crash (note the run still printed `18.98s [OK]` right after the error spam). It self-repeats every flush because `dspy-o11y-langfuse`'s OTel SDK configuration is a *one-shot* decision made as a side effect of `require "dspy"` (itself pulled in by `require "sfl-compiler"`) — by the time any code inside the gem runs, that decision is already locked in for the rest of the process, per the existing comment at the top of `bootstrap.rb`.

**Why the fix lives in `exe/sfl-analyze`, not `Bootstrap`**: the only point where unsetting `LANGFUSE_PUBLIC_KEY`/`SECRET_KEY` can still prevent the broken config is *before* `require "sfl-compiler"` itself — i.e. before any gem code, including `Bootstrap`, has run at all. `SFL::Compiler::LangfuseReachability` is deliberately excluded from Zeitwerk autoloading (`loader.ignore`) and loaded via a direct `require_relative` from the binstub for exactly this reason.

**Behavior**: a quick TCP-connect check against `LANGFUSE_HOST` (2s timeout) before anything else. If unreachable: prints the explanation, then — interactive session → prompts continue-without-tracing (y) or cancel (anything else/EOF); non-interactive session (CI, redirected stdin) → auto-continues without tracing rather than hanging on input that'll never come, after printing the same explanation.

Verified: 9 new specs (`.reachable?` against a real `TCPServer` for true and a closed port for false — no `Socket` mocking; `.decide` covering all branches). Full suite 397/0, rubocop clean. **Live reproduction of the original bug's exact scenario**: ran with `LANGFUSE_HOST` pointed at an unreachable address and stdin from `/dev/null` — prints the warning once, auto-skips tracing, completes the run normally with *zero* OTel decode-error spam (confirmed by direct comparison against the original report's log).