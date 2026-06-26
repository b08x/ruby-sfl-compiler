From README.md's "Parallel Conversation Analysis (Gush / Sidekiq)" section, written 2026-06-24 right after the workflow shipped (`docs/superpowers/plans/2026-06-24-gush-conversation-workflow.md`, commits `966c0b5..2769254`):

> Not yet supported by this workflow: the optional topic-modeling pre-pass, and an equivalent for `documentation`. `ReduceTurnsJob`'s output currently forwards only `metadata`/`insights`, not the full per-speaker profiles or correlations — fine for confirming the workflow ran, not yet a drop-in replacement for `ConversationAnalyzer#analyze`'s return value.

Three gaps, three cards:
1. **Topic-modeling pre-pass** — new, not tracked elsewhere yet.
2. **DocumentationAnalyzer equivalent** — already tracked as a card under `tui-overhaul-gush-sidekiq-backed-pycall-safe` (cross-referenced here rather than duplicated).
3. **ReduceTurnsJob full-output forwarding** — same: already tracked under the TUI track (it's a prerequisite for that track's TUI consumer), cross-referenced here rather than duplicated.

This track exists so "is the Gush workflow itself done" has its own home, separate from "is the TUI rebuilt on it" — they're related but have different definitions of done.
