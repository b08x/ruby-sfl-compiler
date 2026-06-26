## Why this track exists

`sfl-analyze conversation --live` (and the documentation equivalent) hard-freezes/segfaults today. Root cause (confirmed, not guessed — full writeup in `.claude/skills/sfl-tui/references/known-issues.md`): `BatchApp#init` runs Pass 1 (spaCy via PyCall) inside a `Thread.new` spawned by Bubbletea's `execute_batch_sync`, and PyCall's own README states it does not support multi-threaded use. The crash is a `[BUG] Segmentation fault` inside `pycall/pyobject_wrapper.rb`.

As of 2026-06-24, a separate initiative (5-task plan, `docs/superpowers/plans/2026-06-24-gush-conversation-workflow.md`, all tasks complete + SIFT-audited at 88.15/100, commits `966c0b5..2769254` on `development`) decomposed `ConversationAnalyzer#analyze` into a `Gush::Workflow`: `CompileTurnJob` (one per turn, runs Pass 1+2) fans out across **separate Sidekiq worker processes** — each with its own Python interpreter — then fans into `ReduceTurnsJob`. This sidesteps the PyCall/thread restriction entirely, because the parallelism is process-level, not thread-level, inside one TUI process.

## Goal for this track

Rebuild the TUI's live-progress view on top of that Gush workflow instead of `BatchApp`'s broken in-process-thread design: the TUI process creates/starts a `ConversationAnalysisWorkflow`, then polls Gush/Redis for job status (no PyCall touched inside the TUI process at all — it only ever talks to Redis/Postgres, mirroring how `proc-tui`'s `ProcessManager` monitors real OS subprocesses rather than sharing one process's interpreter state across threads).

## Known constraints / things not to relitigate

- PyCall is single-thread only — this is upstream gem behavior, not something to "fix" by retrying differently.
- The Gush workflow currently only supports the `topics: nil` path (no topic-modeling pre-pass) and `ReduceTurnsJob#output` only forwards `metadata`/`insights`, not the full `speaker_profiles`/`tenor_timeline`/`correlations`/`key_moments` — both are tracked as backlog items from the SIFT audit and will need addressing before/while building the TUI consumer.
- `DocumentationAnalyzer` has no equivalent Gush decomposition yet — only `ConversationAnalyzer` does.
- See `.claude/skills/sfl-tui/SKILL.md` for the existing two UI modes in this codebase (sequential Gum wizards vs. full-screen Bubbletea) and which one fits which kind of feature.
