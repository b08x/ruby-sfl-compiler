---
name: sfl-tui
description: Build or extend Bubbletea/Lipgloss/Gum terminal UI screens for sfl-compiler's `sfl-analyze tui`. Use whenever adding a new TUI view, wizard, live-progress screen, or chat-style interface with the bubbletea, bubbles, lipgloss, gum, huh, or glamour Ruby gems in this project — and especially before touching anything that calls Pass 1 (spaCy/PyCall) from a TUI, since there's a confirmed thread-safety trap there. Make sure to consult this skill even if the user just says "add a screen to the tui" or "the --live view is broken" without naming a gem.
---

# sfl-compiler TUI (Charm Ruby)

This project's interactive TUI lives at `lib/sfl/compiler/tui/` (menu + wizards) and
`lib/sfl/compiler/chat/` (full-screen chat), built on the Ruby ports of Charm's
terminal libraries: `bubbletea`, `bubbles`, `lipgloss`, `gum`, `huh`, `glamour`.
Entry point: `bundle exec sfl-analyze tui` → `CLI.run_tui` → `TUI::Menu#run`.

**Read `references/known-issues.md` before working on anything `--live` or
anything that touches Pass 1 from inside a TUI screen.** There is a confirmed,
documented segfault there — don't rediscover it.

## The two UI modes in this codebase

sfl-compiler deliberately keeps **two separate interaction styles**, and picking
the right one for a new feature matters more than gem API trivia:

1. **Sequential Gum prompts, no alt-screen** — `TUI::Menu` and `TUI::Wizards::*`.
   Each wizard is a plain top-to-bottom script: `Gum.input`, `Gum.choose`,
   `Gum.file`, returning a value or `nil` (`nil` = user hit Esc/Ctrl+C = cancel
   back to the menu). The wizard then calls the *exact same* `CLI.run_*` method
   the non-interactive CLI uses — the wizard is just a friendlier way to build
   the options hash. Output prints to stdout normally; there's no persistent
   screen to manage.

   Use this mode for: any one-shot "collect some inputs, then run an existing
   CLI subcommand" feature. It's the cheapest mode — no `Bubbletea::Model`,
   no render loop, no state machine.

2. **Full-screen Bubbletea app** — `Chat::App`. A persistent `Bubbletea::Model`
   with `init`/`update`/`view`, alt-screen, a scrollable `Bubbles::Viewport`,
   and a `Bubbles::TextInput`. Use this mode only when the feature genuinely
   needs a persistent, redrawing screen — multi-turn interaction, live-updating
   panes, anything that isn't "ask N questions, run one command, print output."

Don't reach for full Bubbletea when a wizard would do — `proc-tui` (the demo
this skill also draws from) earns its complexity because it's monitoring
multiple long-running processes simultaneously; most sfl-analyze TUI features
don't have that requirement.

## Pattern: a wizard (Gum prompts → existing CLI method)

Real example, `lib/sfl/compiler/tui/wizards/context_wizard.rb`:

```ruby
require "gum"

class ContextWizard
  MOODS = ["(any)", *ClassificationRegistry.canonical_values(:mood)].freeze

  def run
    query = Prompts.blank_to_nil(Gum.input(header: "Query"))
    return unless query                      # nil = cancelled, bail out

    mood = Gum.choose(MOODS, header: "Mood filter")
    limit = Prompts.optional_int(Gum.input(value: "10", header: "Max clauses")) || 10

    filters = {}
    filters[:mood] = mood if mood && mood != "(any)"

    CLI.run_context(query, { output_dir: nil, limit:, filters: })
  end
end
```

Shared helpers live in `Wizards::Prompts` (`lib/sfl/compiler/tui/wizards/prompts.rb`):
`blank_to_nil`, `optional_int`, `optional_float` — Gum's text inputs return `""`
not `nil` for "left blank", so every wizard needs this normalization. Reuse it;
don't reinvent blank-checking per wizard.

**Known gum-ruby (v0.3.2 wrapping CLI v0.17.0) gotcha:** `Gum.file(directory: false)`
emits `--no-directory` on the real `gum` binary, which v0.17.0 rejects (its
negation support only covers `--permissions`/`--size`). Omit `directory:` entirely
when you mean "files only" rather than passing `false` explicitly — see the
comment in `conversation_wizard.rb` for the verified detail.

To register a new wizard: add the class under `tui/wizards/`, add it to
`TUI::Menu::ACTIONS` and the `dispatch` case in `lib/sfl/compiler/tui/menu.rb`.
`Menu#dispatch` wraps every wizard call in `safe_run`, which rescues
`SFL::Compiler::Error`/`DSPy::LM::AdapterError` and prints `[ERROR]` rather than
crashing the menu loop — follow that convention; don't add your own rescue in
the wizard unless you need a different message.

## Pattern: a full-screen Bubbletea app

Real example (trimmed), `lib/sfl/compiler/chat/app.rb`:

```ruby
class App
  include Bubbletea::Model

  AnswerMessage = Class.new(Bubbletea::Message) do
    attr_reader :result
    def initialize(result) = (super(); @result = result)
  end

  def initialize(session:, width: 100, height: 24)
    @session = session
    @input = Bubbles::TextInput.new.tap { |i| i.prompt = "> "; i.focus }
    @viewport = Bubbles::Viewport.new(width:, height: height - 3)
    @viewport.style = Styles::VIEWPORT_BORDER
    @spinner = Bubbles::Spinner.new(spinner: Bubbles::Spinners::DOT)
  end

  def init = [self, nil]

  def update(message)
    case message
    when Bubbletea::KeyMessage then handle_key(message)
    when AnswerMessage then handle_answer(message.result)
    when Bubbles::Spinner::TickMessage then update_spinner(message)
    else [self, nil]
    end
  end

  def view
    Lipgloss.join_vertical(Lipgloss::LEFT, header, @viewport.view, input_line, footer)
  end

  # Runs off the UI thread; Bubbletea sends the returned Message back into
  # #update once the lambda completes. Safe here because @session.ask only
  # talks to the LLM/DB over HTTP — no PyCall involved.
  private def ask_command(query)
    lambda do
      AnswerMessage.new(@session.ask(query))
    rescue => e
      ErrorMessage.new(e)
    end
  end
end
```

Key shapes to copy:

- **`update` is a big `case message`** dispatching to small private handlers.
  Every branch returns `[self, command_or_nil]` — `self` (mutated in place) and
  either `nil` or a `Bubbletea::Message`/`Proc`/`Bubbletea.batch(...)` to run next.
- **Background work returns through a `Message`, not a return value.** A `Proc`
  command runs on its own `Thread.new` (see `references/threading.md`); it must
  return a `Bubbletea::Message` subclass (or `nil`), and `update` handles that
  message when it comes back. This is the *only* sanctioned way data crosses
  from background work into the model — never mutate `@ivars` directly from
  inside the lambda, since it's running on a different thread than `update`.
- **One `Styles` module per screen**, not inline `Lipgloss::Style.new` calls
  scattered through view code (`lib/sfl/compiler/chat/styles.rb`). Keeps a
  future palette change a one-file edit.
- **`Bubbles::Viewport` for any scrolling transcript/log**: set `.content`,
  call `.goto_bottom` after appending, render via `.view` inside your own
  `Lipgloss.join_vertical`/`join_horizontal` layout.
- **Glamour for any LLM-authored markdown** going into the transcript
  (`Glamour.render(result.answer)`) — don't hand-roll markdown-to-ANSI.

To wire a new full-screen app into the menu, add it as its own `ACTIONS` entry
in `Menu` and call `Bubbletea.run(YourApp.new(...))` from `dispatch` — see how
`:chat` does it. Don't run a Bubbletea app *inside* a wizard's sequential flow;
keep alt-screen apps as their own top-level menu choice.

## Hard rule: PyCall (spaCy/Pass 1) is single-threaded only

**Never call into Pass 1 (`PassOneEngine`, `ruby-spacy`, anything touching
PyCall) from inside a Bubbletea `Proc` command, a `Thread.new`, or any thread
other than the one that initialized the Python interpreter (normally your
program's main thread).** The official PyCall README says it outright: *"PyCall
does not officially support multi-threaded use... recommends against using
PyCall in multi-threaded environments."* `lib/sfl/compiler/tui/batch_app.rb`
violates this today and segfaults — see `references/known-issues.md` for the
full trace and the fix direction if you're asked to repair it.

LLM calls (Pass 2 / DSPy.rb / `Chat::Session`) are HTTP-based and have no such
restriction — `Chat::App`'s background-thread pattern above is fine specifically
*because* it never touches PyCall.

## References

- `references/threading.md` — how Bubbletea actually schedules commands
  (verified against the installed gem's `runner.rb`), and what's safe vs. unsafe
  to put in a `Proc` command.
- `references/known-issues.md` — the confirmed BatchApp/PyCall segfault: root
  cause, stack trace, and the subprocess-based fix direction if you pick this
  back up.
- `references/gem-cheatsheet.md` — condensed API reference for gum, huh, glamour,
  lipgloss, bubbles, pulled from the upstream Ruby ports' docs (not yet all used
  in this codebase — huh in particular isn't used here yet; Gum prompts cover
  the same ground for the wizards we have).
- `references/proc-tui-patterns.md` — patterns from the `proc-tui` Charm Ruby
  demo worth borrowing for *new* multi-pane/live-monitoring TUI features
  (split view, scroll/filter, tab bar) — useful precedent for replacing
  BatchApp's broken design with a subprocess-monitoring one.
