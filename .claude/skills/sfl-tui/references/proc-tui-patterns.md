# Patterns worth borrowing from the proc-tui demo

Source: `proc-tui` demo in the `ruby-charm` Charm Ruby samples repo
(`proc-tui/lib/{proc_tui,key_handler,renderer,theme,messages,process_manager,procfile_parser}.rb`).
It's a Bubbletea TUI for running/monitoring Procfile processes — structurally
the closest precedent for "live-updating multi-pane view driven by background
work", which is exactly the shape `BatchApp` is trying (and currently failing)
to be. Worth revisiting in full if/when `--live` gets reworked into a
subprocess-based design (see `known-issues.md`).

## The one structural fact that matters most

`proc-tui` **never shares a single interpreter's native state across
threads**. Its `ProcessManager` spawns real OS subprocesses (`IO.popen` /
`Process.spawn`-style) for each Procfile entry and reads their stdout into a
queue; the Bubbletea model just polls that queue on a tick, same shape as
`BatchApp`. The difference that keeps it safe: each monitored process is its
own OS process with its own memory space, so there's no PyCall-style shared
native interpreter to corrupt. This is the template for fixing `BatchApp`:
treat the SFL analysis run the same way proc-tui treats a Procfile entry —
an external process you watch, not in-process work you thread.

## Module split: one responsibility each, mixed into the model

```ruby
class ProcTUI
  include Bubbletea::Model
  include KeyHandler   # def handle_key(message) -> [self, command]
  include Renderer     # def view / render_* helpers, no state mutation
  ...
end
```

`update`'s `Bubbletea::KeyMessage` branch is a one-liner: `handle_key(message)`.
All rendering helpers (`render_header_row`, `render_tabs`, `render_logs`, ...)
live in `Renderer` and take no arguments beyond what's in `@ivars` — they
build strings/joined Lipgloss output, never touch `@theme`/state directly
beyond reading it. This split is worth copying once a single-file `view`
method starts exceeding ~40-50 lines; `Chat::App` and `BatchApp` are still
small enough to stay single-file.

## Tab bar + scrollable log pane (reusable shape)

```ruby
def render_tabs
  @tabs.each_with_index.map do |tab, index|
    is_active = index == @active_tab
    style = is_active ? @theme.active_tab : @theme.tab
    style.render(tab)
  end.join("  ")
end
```

Pairs with `handle_key`'s `tab`/`shift+tab`/number-key branches that mutate
`@active_tab` and reset `@scroll_offset`. If a future sfl-analyze TUI feature
needs "one pane per file" or "one pane per turn", this is the minimal version
of that — simpler than `BatchApp`'s fixed two-pane `join_horizontal` layout
when you need more than two panes or need them switchable.

## Filter-as-mode pattern

```ruby
when "/"
  @filter_mode = true
  @filter_text = ""
...
def handle_filter_key(message)
  case message.to_s
  when "enter", "esc" then @filter_mode = false
  when "backspace" then @filter_text = @filter_text[0...-1]
  else
    character = message.to_s
    @filter_text += character if character.length == 1 && character.match?(/[[:print:]]/)
  end
end
```

`handle_key` checks `return handle_filter_key(message) if @filter_mode` before
its normal `case`. Any "enter a sub-mode that captures different keys" feature
(search, rename, free-text filter) should follow this shape rather than adding
more conditionals into one giant `case`.

## Split-pane / focus-pane view

`render_split_panes` divides `@width` evenly across `@split_panes.length`,
renders each pane's header + visible log lines, and joins them with `"│"` per
row (not as whole blocks — it joins line-by-line so panes stay aligned even
with differing content heights). `render_focused_pane` is the same idea
collapsed to one wide pane plus narrow "hint" columns for the others. Useful
reference if a future feature wants to show, say, multiple files' analysis
progress side-by-side rather than `BatchApp`'s current fixed stats-pane +
log-pane split.

## Status-line composition

```ruby
padding = @width - visible_length(left) - visible_length(right) - 2
padding = [0, padding].max
left + " " * padding + right
```

`visible_length` strips ANSI codes before measuring — necessary any time
you're hand-packing styled strings into a fixed-width line (lipgloss-ruby's
own layout helpers like `join_horizontal` handle this for you when you can
use them instead; reach for this manual approach only when you need
left-and-right-justified content sharing one line, which `join_horizontal`
doesn't directly express).
