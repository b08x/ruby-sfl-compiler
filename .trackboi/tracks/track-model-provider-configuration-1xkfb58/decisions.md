# Decisions

## [accepted] Model registry design: key schema, Bootstrap boundary, capability source

## Decision 1 — Key granularity: literal task names

Use **literal call-site keys** (`pass_two`, `narrative`, `achilles`, `tortoise`, `genie`) not a collapsed role set (`annotation`, `generation`, `verification`). The role-set approach introduces an indirection layer that obscures which actual call site uses which model — "generation" could be narrative or Achilles proposal. Literal names map 1:1 to call sites, are self-documenting, and don't require a mapping table. `crab` is excluded (rule-based, no LLM call).

Config file shape (`~/.config/sfl-compiler/config.yml`):

```yaml
models:
  pass_two: "openrouter/mistralai/mistral-7b-instruct"
  narrative: "openrouter/anthropic/claude-haiku-20240307"
  achilles:  "openrouter/anthropic/claude-3-sonnet-20240229"
  tortoise:  "openrouter/google/gemini-flash-1.5"
  genie:     "openrouter/anthropic/claude-opus-4"
```

## Decision 2 — Bootstrap boundary

**Bootstrap owns the model registry** — no second config entry point. Bootstrap is already the project's documented single ENV reader and sole configuration surface. It will: (1) build a `TTY::Config` instance searching `~/.config/sfl-compiler/` then the project root; (2) read the config file if it exists; (3) expose `ctx.model_for(task)` that returns the configured provider string, falling back to `ctx.config.dspy_provider` for any unconfigured task. This preserves the invariant that callers never read ENV or files themselves.

```ruby
# In Bootstrap.call — sketch only, implementation is a follow-up card
config_store = TTY::Config.new
config_store.filename = "config"
config_store.append_path(File.join(Dir.home, ".config", "sfl-compiler"))
config_store.append_path(Dir.pwd)
config_store.read if config_store.exist?

# ctx.model_for(:pass_two) → config_store.fetch(:models, :pass_two, default: global_provider)
```

## Decision 3 — Capability source: RubyLLM model catalog

Use **`RubyLLM.models.all`** (already a gem dependency) for model listing and capability filtering. It provides an up-to-date catalog per-provider without querying OpenRouter's `/models` endpoint directly or hand-maintaining a capability table. Filter candidates by `supports_functions: true` for sprint roles (structured outputs). CLI prompt (`tty-prompt` `select`) presents filtered list; React settings screen (Phase 3) consumes the same list via a Falcon `GET /models` endpoint.

## tty-config API confirmed via Context7

```ruby
# lib/sfl/compiler/model_registry.rb (new, follow-up card)
require "tty-config"

class ModelRegistry
  TASK_KEYS = %w[pass_two narrative achilles tortoise genie].freeze

  def self.build(fallback_provider:)
    cfg = TTY::Config.new
    cfg.filename = "config"
    cfg.append_path(File.join(Dir.home, ".config", "sfl-compiler"))
    cfg.append_path(Dir.pwd)

    TASK_KEYS.each do |task|
      cfg.validate(:models, task) do |key, value|
        unless value.is_a?(String) && value.include?("/")
          raise TTY::Config::ValidationError,
                "#{key} must be a provider/model string, got: #{value.inspect}"
        end
      end
    end

    cfg.read if cfg.exist?
    new(cfg, fallback_provider:)
  end

  def initialize(cfg, fallback_provider:)
    @cfg = cfg
    @fallback = fallback_provider
  end

  def for(task)
    @cfg.fetch(:models, task.to_s, default: @fallback)
  end

  def write_defaults(path)
    TASK_KEYS.each { |t| @cfg.set(:models, t, value: @fallback) }
    @cfg.write(path, force: true, create: true)
  end
end
```

## Follow-up cards needed (not this card)

1. Implement `ModelRegistry` + wire into `Bootstrap.call` → `ctx.model_for`
2. Update `SprintRoleJob`, `PassTwoEngine`, `NarrativeGenerator` call sites to use `ctx.model_for(:task)` instead of hardcoded provider strings
3. Add `sfl-analyze config init` subcommand that writes a default config file via `ModelRegistry#write_defaults`
