---
name: sfl-analyze
description: Generate SFL analysis scripts for conversations, documentation, and context extraction
---

# SFL Analysis Skill

Generates custom analysis scripts using the SFL compiler framework.

## Usage

```bash
# Analyze conversation (JSONL format)
/sfl-analyze conversation <path> [options]

# Future subcommands (not yet implemented):
# /sfl-analyze documentation <path> [options]
# /sfl-analyze context <query> [options]
# /sfl-analyze generate-script "<description>"
```

## Subcommands

### `conversation`

Analyzes chat logs, transcripts, or turn-based conversations.

**Arguments**:
- `<path>`: Path to JSONL file (required)

**Options**:
- `--output-dir <dir>`: Output directory [default: ./sfl_output]

**Example**:
```bash
/sfl-analyze conversation chat.jsonl
/sfl-analyze conversation chat.jsonl --output-dir ./results
```

**What it does**:
1. Loads JSONL conversation (format: `{name, send_date, mes}`)
2. Compiles each turn through SFL pipeline (Pass 1 + Pass 2)
3. Tracks tenor evolution (formality shifts)
4. Builds speaker profiles (avg tenor, modality, mood distribution)
5. Correlates process types with tenor/modality
6. Generates insights
7. Exports to CSV + JSON + Markdown

**Output Files**:
- `conversation_analysis.csv` — Turn-by-turn data for spreadsheet analysis
- `conversation_analysis.json` — Structured data for programmatic access
- `conversation_analysis.md` — Human-readable report with insights

---

## Script Location

The skill runs the existing template script:
- `scripts/sfl_analysis/templates/conversation_analysis_template.rb`

---

## Examples

**Example 1: Analyze support conversation**
```bash
/sfl-analyze conversation support_chat.jsonl
```

**Example 2: Custom output directory**
```bash
/sfl-analyze conversation meeting_transcript.jsonl --output-dir ./analysis_results
```

---

## Requirements

- PostgreSQL database with pgvector extension
- spaCy with `en_core_web_sm` model
- OpenAI API key (for Pass 2 interpersonal annotation)

Set via environment variables:
```bash
export DATABASE_URL="postgresql:///sfl_compiler_dev"
export OPENAI_API_KEY="sk-..."
```
