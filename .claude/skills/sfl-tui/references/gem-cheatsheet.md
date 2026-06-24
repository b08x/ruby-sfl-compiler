# Charm Ruby gem cheatsheet

Condensed from each gem's own docs (via Context7 — `/marcoroth/gum-ruby`,
`/marcoroth/huh-ruby`, `/marcoroth/lipgloss-ruby`, `/marcoroth/glamour-ruby`,
`/marcoroth/bubbles-ruby`). Re-verify exact method signatures against Context7
or `gem contents <gem>` before relying on anything here for unfamiliar calls —
this file is a map of what's available, not a guarantee of exact current API.

**Already used in this codebase:** gum, bubbletea, bubbles (`Viewport`,
`TextInput`, `Spinner`), lipgloss, glamour. **Not used yet:** huh, harmonica,
ntcharts — listed below in case a future feature wants them, but there's no
in-repo precedent to copy from for these.

## gum — sequential prompts (what `tui/wizards/` is built on)

```ruby
require "gum"

Gum.input(header: "Query", value: "default", placeholder: "hint")  # -> String or nil (Esc/Ctrl+C)
Gum.choose(["a", "b", "c"], header: "Pick one")                     # -> String or nil
Gum.choose(items, no_limit: true, header: "Toggle (tab/space)")     # -> Array or []
Gum.file(file: true, directory: true)                               # -> path String or nil
Gum.confirm("Proceed?")                                             # -> true/false

# Standalone styling/formatting/layout (rarely needed here — Lipgloss covers
# most of this codebase's styling already)
Gum.style("text", foreground: "212", border: :rounded, padding: "1 2")
Gum.format("# Heading", type: :markdown)
Gum.join(box1, box2, vertical: true, align: :center)

Gum.executable   # path to the resolved gum binary (gem-managed, may differ from system PATH)
Gum.version      # gem + upstream CLI version
```

Every `Gum.*` prompt returns `nil` on Esc/Ctrl+C — this codebase's convention
(see every `tui/wizards/*.rb`) is `return unless value` immediately after each
required prompt, which cancels the whole wizard back to the menu. Follow that,
don't add custom cancel-handling per wizard.

`GUM_INSTALL_DIR` env var overrides where the gem looks for its `gum` binary —
relevant only if debugging a "gum not found"-type error, not for normal use.

## huh — declarative forms (not used in this repo yet)

Gum prompts cover every wizard so far; reach for huh only if a feature needs
genuine multi-field forms with cross-field validation in one screen (huh
validates per-field and blocks submission until valid) rather than a sequence
of independent Gum prompts.

```ruby
require "huh"

form = Huh.form(
  Huh.group(
    Huh.input.key("name").title("What's your name?").validate(Huh::Validation.not_empty),
    Huh.select.key("role").title("Role").options("Developer", "Designer")
  )
)
form.run
form["name"]  # collected values by key

# Validators
Huh::Validation.not_empty
Huh::Validation.min_length(3) / .max_length(100) / .length(3, 20)
Huh::Validation.email / .integer / .range(1, 100)
Huh::Validation.matches(/regex/, message: "...")
Huh::Validation.one_of("small", "medium", "large")
Huh::Validation.all(v1, v2, ...)                 # combine
form.with_validate_on_submit(true)               # block until all valid

# Spinner for a blocking action with built-in error surfacing
error = Huh.spinner.title("Saving...").type(:dots).action { save_data }.run
puts "Failed: #{error.message}" if error
```

## lipgloss — styling and layout (used throughout `chat/styles.rb`, `tui/theme.rb` pattern)

```ruby
require "lipgloss"

style = Lipgloss::Style.new
  .bold(true).italic(false).foreground("212").background("0")
  .border(Lipgloss::ROUNDED_BORDER)              # or :rounded/:double/:thick/:normal/:hidden/:none
  .padding(0, 1)                                  # or padding_left/padding_right/padding_top/padding_bottom
  .width(50).align(Lipgloss::CENTER)
style.render("text")

# Layout composition (prefer these over manual string-padding)
Lipgloss.join_vertical(Lipgloss::LEFT, block1, block2, block3)
Lipgloss.join_horizontal(Lipgloss::TOP, pane1, pane2)

# Color gradients
Lipgloss::ColorBlend.blend(color1, color2, point, mode: :luv)  # :luv (default, perceptual) / :rgb / :hcl
Lipgloss::ColorBlend.blends(color1, color2, steps: 10)
```

This codebase's convention: one `Styles`/`Theme` module per screen holding
named `Lipgloss::Style.new` constants/methods (`chat/styles.rb`,
`proc-tui/lib/theme.rb`) — never inline `Lipgloss::Style.new` calls scattered
through `view`/`render_*` methods.

## glamour — markdown-to-ANSI rendering (used in `Chat::App` for LLM answers)

```ruby
require "glamour"

Glamour.render(markdown_string)                          # auto-detected style
Glamour.render(markdown_string, style: "dark")            # "auto"/"dark"/"light"/"notty"/"dracula"
Glamour.render(markdown_string, width: 80, emoji: true, preserve_newlines: true)

# Custom style hash (rarely needed — only if the default themes don't fit)
Glamour.render_with_style(markdown_string, { heading: { color: "212", bold: true }, ... })
```

`style: "notty"` is the one worth remembering for anything that might run in a
non-interactive/CI context — it strips colors deterministically rather than
relying on auto-detection.

## bubbles — reusable Bubbletea widgets (Viewport/TextInput/Spinner used in `chat/app.rb`)

```ruby
require "bubbles"   # umbrella require; loads cursor.rb before text_input.rb needs it

viewport = Bubbles::Viewport.new(width:, height:)
viewport.style = my_border_style
viewport.content = transcript_lines.join("\n\n")
viewport.goto_bottom
viewport.view   # -> rendered String, fold into your own Lipgloss layout

input = Bubbles::TextInput.new
input.prompt = "> "; input.placeholder = "..."; input.focus
input, command = input.update(message)   # call from your update(), threads command through

spinner = Bubbles::Spinner.new(spinner: Bubbles::Spinners::DOT)  # also :LINE, :MINI_DOT, :MOON, etc.
spinner.tick                              # initial command to kick off animation
spinner, command = spinner.update(message)
spinner.view

# Not yet used here, available if needed:
Bubbles::List.new(items, width:, height:)   # .title=, .selected_index, .items=
Bubbles::Key.binding(keys: ["up", "k"], help: ["↑/k", "up"])
Bubbles::Key.matches?(message, binding)
Bubbles::Help.new
```

Every bubbles widget follows the same `widget, command = widget.update(message)`
threading convention as the top-level `Bubbletea::Model#update` — forward the
returned `command` up through your own `update`'s return value rather than
discarding it, or you'll silently drop things like the spinner's next tick.

## Not used in this codebase — only mentioned for completeness

- **harmonica** — physics-based spring animations (smooth value interpolation
  for things like animated progress bars or sliding panels). No precedent here.
- **ntcharts** — terminal charts (sparklines, bar charts, line graphs). Could
  replace `BatchApp`'s plain text mood/process-type tally lines with an actual
  bar chart if that's ever wanted — no current usage to copy from.
