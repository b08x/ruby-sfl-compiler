# Bubbletea command threading (verified against installed gem 0.1.4)

Source checked: `lib/bubbletea/runner.rb` in the installed `bubbletea-0.1.4`
gem (path varies by platform gem name, e.g.
`bubbletea-0.1.4-x86_64-linux-gnu`). Re-verify against whatever version is
actually installed if behavior seems off — gem internals aren't a stable
public API and can change between versions.

## What runs where

`Bubbletea::Program#update` results in a command (or `nil`). Commands are
dispatched through `execute_command_sync`:

| Command type | Where it runs |
|---|---|
| `Proc` | **`Thread.new { command.call }`** — a new OS-level Ruby thread, joined back into the message loop when it returns |
| `BatchCommand` (`Bubbletea.batch(*cmds)`) | **one `Thread.new` per command**, all joined together (`execute_batch_sync`) |
| `SequenceCommand` (`Bubbletea.sequence(*cmds)`) | each command in order, **on the calling thread** — no extra threads |
| `TickCommand` (`Bubbletea.tick(seconds) { ... }`) | scheduled via `schedule_tick`, fires on the runner's own timer, not a fresh thread per tick |
| `QuitCommand`, `SendMessage`, alt-screen toggles, etc. | synchronous, on the calling thread |

The two threading-relevant facts:

1. **A bare `Proc` command (and every command inside a `Bubbletea.batch`) gets
   its own thread.** This is real OS-level concurrency, not cooperative —
   confirmed by reading `execute_command_sync`/`execute_batch_sync` directly
   (the in-repo comment in `batch_app.rb` calls this "confirmed live against
   the installed gem's runner.rb", and it's correct on that narrow point).
2. **Bubbletea has no documented API for a thread to push a `Message` into a
   *running* program from outside the command-return mechanism.** The
   sanctioned path is: your `Proc` finishes and returns a `Bubbletea::Message`
   subclass, which `update` then receives. If you need many incremental
   updates from one long-running operation (not just one final result), you
   can't keep calling back into `update` directly from the worker thread —
   instead push onto a thread-safe `Queue` from the worker and drain it on a
   fast recurring `Bubbletea.tick`. That's exactly what `BatchApp` does for
   per-turn progress, and the pattern itself (Queue + tick-poll) is fine —
   it's *what's running on the producer thread* that matters.

## What's safe to put inside a `Proc` command

Safe: anything that's just Ruby + I/O — HTTP calls (DSPy/LLM requests,
`Chat::Session#ask`), database queries (Sequel/pg), file I/O, shelling out to
another OS process. `Chat::App#ask_command` is the model: it calls
`@session.ask(query)`, which only talks to an LLM and Postgres over the
network — no shared native interpreter state to worry about.

**Unsafe:** anything that holds a C-extension-managed interpreter or
non-thread-safe native state shared with the rest of the process — the
concrete instance in this codebase is **PyCall** (used by `ruby-spacy` for
Pass 1). See `references/known-issues.md` for the segfault this causes and
why "wrap it in `Thread.new`" is never the right call for that specific
dependency, no matter how the threading is structured around it.

If you're unsure whether a gem is safe to call from a Bubbletea `Proc`
command, the question to answer is "does this gem embed or bind to a
non-Ruby runtime with its own concurrency model" (Python via PyCall/FFI,
a native extension with global mutable state, etc.) — if yes, keep it off
any thread other than the one that initialized it, full stop.
