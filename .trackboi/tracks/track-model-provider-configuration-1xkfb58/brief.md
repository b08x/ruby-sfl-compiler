## Why this exists

Today model selection is one global knob: `SFL::Compiler.config.dspy_provider` / `DSPY_PROVIDER` env var, read once in `Bootstrap.call` (`lib/sfl/compiler/bootstrap.rb`). Every DSPy call in the process — Pass 2 batch annotation, narrative generation, and (per the new `track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi`) each of Achilles/Tortoise/Crab/Genie — uses the same model unless a caller hand-builds its own `DSPy::LM.new(...)`, which `SprintRoleJob` already does per-instance (`params.fetch(:lm)`).

The user wants this to grow into a real settings surface: eventually a UI screen (likely the React/google-ai-studio frontend mentioned in the broader "parallel processing + UI + falcon/async backend" restructure the user is independently working through) where you pick which model handles which task. Before that UI exists, the immediate, buildable step is a config-file-backed model registry on the CLI side.

## Two distinct concerns, don't conflate

1. **Per-task model assignment** — "Pass 2 annotation uses model A, narrative generation uses model B, Achilles uses model C, Tortoise uses model D." This is just configuration plumbing: a place to declare `{task_name: provider_string}` pairs and a lookup `Bootstrap`/callers use instead of the single global `dspy_provider`.
2. **Capability-filtered model *listing*** — when presenting a model picker (CLI prompt now, UI dropdown later), the candidate list must already be filtered to models that support what the task structurally requires: DSPy.rb's structured-outputs mode (`structured_outputs: true` in `Bootstrap#build_lm`/`SprintRoleJob#build_lm`), tool/function calling (used by sprint roles per the shared substrate track), and "reasoning" models (the ChainOfThought pattern this whole pipeline is built on benefits from but doesn't strictly require a reasoning-tagged model). Showing every model a provider offers, including ones that silently fail or degrade on structured output, just reproduces the Card #8/#9-era "live run reveals it's broken" pattern one layer up — at config time instead of compile time.

## Candidate tech: tty-config

User suggested `tty-config` (part of the TTY toolkit already used elsewhere per the `ruby-dev` skill's `tui_builder` agent) for the config-file layer — XDG-aware config file read/write, nested key access, validation. Fits this codebase's existing CLI-first, no-Rails-magic style. Needs Context7 verification of the actual `tty-config` API before any code lands (per this project's "verify gem APIs via Context7, not source" standing practice) — not yet done, this is a starting pointer, not a confirmed design.

## Open questions (not yet resolved)

- Where does the capability metadata per model come from? Hand-maintained list (config file) vs. querying each provider's models endpoint vs. OpenRouter's own model-capability metadata (since OpenRouter is the provider already in `.env` per project docs) — OpenRouter's `/models` endpoint does return per-model `supported_parameters` including structured outputs/tools, which is the most promising path to avoid hand-maintaining a capability table that goes stale.
- Per-task config keys: does this key off the literal call sites (`pass_two`, `narrative`, `achilles`, `tortoise`, `crab`, `genie`) or a smaller set of *roles* (`annotation`, `generation`, `verification`) that call sites map onto? Smaller role set is probably more durable as new tracks add new call sites, but not decided.
- Relationship to `Bootstrap`: `Bootstrap.call` is documented project-wide as "the ONLY ENV reader" (`CLAUDE.md` gotcha and architecture section). A config-file-backed model registry either lives inside Bootstrap's responsibility or is a deliberate, documented second config entry point — needs an explicit decision, not a default.
- This track's eventual UI consumer is out of scope for sfl-compiler itself if the UI ends up as a separate React app per the user's broader restructure — likely this track only owns the config schema + capability-filtered listing logic + a CLI prompt UI, with the future React settings screen as a separate consumer hitting whatever this track exposes (API endpoint, once falcon/async backend exists, or a shared config file format).

## Relationship to other tracks

Cross-cutting: every sprint-role track (`track-shared-sprint-role-substrate-sprintrolejob-crabc-1vfz8vi` and its three consumers) already does manual per-instance LM config (`params.fetch(:lm)` as a raw provider string). This track doesn't change that mechanism — it changes *where the provider string comes from* (a configured per-task registry instead of a hardcoded literal in each card's `domain_payload`).
