---
name: sfl-analyze
description: Run SFL analyses (conversations, documentation, context queries) via the sfl-analyze CLI
---

# SFL Analysis Skill

Runs analyses through the gem's `sfl-analyze` executable. All logic lives in
the library (`lib/sfl/compiler/analysis/`, `lib/sfl/compiler/retrieval/`);
this skill only composes CLI invocations.

## Subcommands

```bash
# Conversation (JSONL: {name, send_date, mes} per line)
bundle exec sfl-analyze conversation chat.jsonl [--output-dir DIR] [--pass1-only] [--narrative]

# Documentation (markdown file or directory)
bundle exec sfl-analyze documentation docs/ [--output-dir DIR] [--pass1-only] [--store] [--narrative]

# Context query over stored clauses (requires a prior --store ingestion)
bundle exec sfl-analyze context "how does X work?" \
  [--mood declarative] [--min-tenor 0.5] [--max-tenor 1.0] \
  [--min-modality 0.0] [--max-modality 1.0] [--limit 10] [--output-dir DIR]

# Narrative report from an existing analysis JSON (must contain a `turns` array)
bundle exec sfl-analyze narrate conversation_analysis.json [--output-dir DIR]
```

## Outputs

conversation/documentation write `conversation_analysis.{csv,json,md}` into
`--output-dir` (default `./output/latest`). Reports include a Data Quality
section whenever clauses carry fallback/stub interpersonal values, plus
Cohesion Metrics (repetition/conjunction/pronoun density per turn or
section), ⚡ Key Moments (tenor/modality shifts beyond threshold), and 📖
Example Passages (most formal/casual/certain/hedged). `--narrative`
additionally writes `narrative_report.md` (one LLM call) after the trio;
failure only warns, the analysis output is unaffected.
`context` prints the synthesized answer + cited evidence; `--output-dir`
additionally writes `context_synthesis.json`.

## Requirements

`.env` with `DATABASE_URL`, `DSPY_PROVIDER`, and the matching API key
(`OPENROUTER_API_KEY` / `GOOGLE_API_KEY` / `OPENAI_API_KEY` /
`ANTHROPIC_API_KEY`). PostgreSQL needs the `vector` and `pg_trgm`
extensions; Pass 1 needs spaCy with `en_core_web_sm`.

## Custom analyses

For bespoke needs, compose the library directly instead of generating a
script: `Bootstrap.call` → `Pipeline` → `Analysis::ConversationAnalyzer` /
`Analysis::DocumentationAnalyzer` / `ContextSynthesizer` →
`Formatters::ReportWriter`. See `lib/sfl/compiler/cli.rb` for the wiring.
