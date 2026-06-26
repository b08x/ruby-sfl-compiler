# Known Issues

## `sfl-analyze conversation/documentation ... --live` segfaults (hard freeze)

**Status:** FIXED in BatchApp rewrite (commit on development branch). `BatchApp`
no longer runs Pipeline/spaCy in a thread — it only polls Redis via
`WorkflowPoller`. The Gush `ConversationAnalysisWorkflow` runs actual work in
separate Sidekiq OS processes. Requires Redis + `bundle exec sidekiq -q gush`
running before invoking `--live`. Documentation `--live` not yet wired.

**Symptom:** running with `--live` appears to hard-freeze the terminal partway
through analysis. It's not actually a hang — the process segfaults
(`[BUG] Segmentation fault`), and because Bubbletea had put the terminal into
alt-screen/raw mode, the shell is left looking stuck until you reset it.

**Root cause:** `BatchApp#init` (`lib/sfl/compiler/tui/batch_app.rb`) calls

```ruby
[self, Bubbletea.batch(schedule_poll, run_analysis)]
```

Bubbletea's `execute_batch_sync` (gem `bubbletea` 0.1.4, `lib/bubbletea/runner.rb`):

```ruby
def execute_batch_sync(commands)
  threads = commands.map { |cmd| Thread.new { execute_command_sync(cmd) } }
  threads.each(&:join)
end
```

spawns **one OS-level Ruby thread per batch command** and runs them concurrently.
`run_analysis`'s lambda calls `ConversationAnalyzer#analyze` →
`PassOneEngine#process` → `ruby-spacy`'s `Language#read` → PyCall's
`call_object` — i.e. it invokes spaCy through PyCall from a background thread
while Bubbletea's own poll/tick/render machinery is alive on other threads in
the same process.

The official PyCall README states this directly:

> **Multi-threaded use**: PyCall does not officially support multi-threaded
> use because managing the CPython Global Interpreter Lock (GIL) in a stable
> way across all situations is highly complex... the project maintains that
> the cost of supporting multi-threaded concurrency is too high, and therefore
> recommends against using PyCall in multi-threaded environments.

That's the exact crash, captured in a real run:

```
pycall/pyobject_wrapper.rb:93: [BUG] Segmentation fault at 0x0000000000000010
...
c:0021 ... pycall/pyobject_wrapper.rb:93   call_object
c:0020 ... ruby-spacy.rb:95                Language#initialize
c:0019 ... ruby-spacy.rb:536                Language.new / #read
c:0017 ... pass_one_engine.rb:50            PassOneEngine#process
c:0016 ... pipeline.rb:58                   Pipeline#compile
c:0015 ... conversation_analyzer.rb:315     #compile_clauses
c:0014 ... conversation_analyzer.rb:281     #compile_turn
c:0008 ... batch_app.rb:139                 run_analysis's lambda (in Thread.new)
c:0003 ... bubbletea/runner.rb:296          execute_command_sync
```
`Ruby thread count for this ractor: 5` at crash time — multiple threads alive,
exactly the configuration PyCall warns against.

**Why this is architectural, not a one-line bug:** the code comment inside
`batch_app.rb` explicitly claims the background-thread approach was "confirmed
live against the installed gem's runner.rb" as a safe way to keep Pass 1/Pass 2
off the UI thread. That confirmation was about Bubbletea's threading model, not
about whether the *work being threaded* (PyCall) tolerates it. Any future
live-progress feature that touches Pass 1 inherits this same trap if it follows
the same pattern.

**Fix direction discussed but not implemented** (revisit if asked to repair
`--live`): don't share one process's Python interpreter across Ruby threads at
all. Run the actual analysis as a **separate OS subprocess** — e.g. shell out to
`sfl-analyze conversation ...` itself (or a small dedicated worker script), let
it print NDJSON progress lines to stdout, and have `BatchApp`'s tick-driven
poller read them off a pipe exactly the way `proc-tui`'s `ProcessManager`
streams subprocess output into its own queue (see `references/proc-tui-patterns.md`).
Each subprocess gets its own Python interpreter, so PyCall's single-thread
requirement is satisfied trivially — there's no thread-sharing to worry about.
Pass 2 (DSPy/LLM calls) has no such restriction and can stay exactly as it is
if/when this gets reworked.

**What's unaffected:** the plain (non-`--live`) `sfl-analyze conversation` and
`sfl-analyze documentation` subcommands call Pass 1 synchronously on the main
thread — no Bubbletea, no extra threads, no PyCall conflict. Only the
Bubbletea-backed `--live` view is broken.

## gum-ruby (0.3.2 / CLI v0.17.0) `--no-directory` bug

`Gum.file(directory: false)` emits `--no-directory` to the underlying `gum`
binary. The installed `gum` CLI's negation allowlist only covers
`--permissions`/`--size`, so it rejects the flag with `unknown flag
--no-directory`. Workaround used throughout `tui/wizards/`: omit `directory:`
entirely (its documented default already matches what you want) rather than
passing `false` explicitly. See `conversation_wizard.rb`'s comment for the
verified detail — re-check against whatever `gum`/`gum-ruby` version is
installed if this surfaces again, since it's a version-specific CLI bug, not
a gem bug.
