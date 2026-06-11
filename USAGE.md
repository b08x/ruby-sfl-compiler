# SFL Compiler Usage Guide

## Quick Start

### 1. Configure Environment

Edit `.env` and add your API key:

```bash
# For OpenAI (default)
OPENAI_API_KEY=sk-your-key-here
DSPY_PROVIDER=openai/gpt-4o-mini

# OR for Anthropic
ANTHROPIC_API_KEY=your-key-here
DSPY_PROVIDER=anthropic/claude-3-5-sonnet-20241022

# OR for OpenRouter
OPENROUTER_API_KEY=your-key-here
DSPY_PROVIDER=openrouter/anthropic/claude-3.5-sonnet
```

### 2. Run Conversation Analysis

```bash
# Using the skill
/sfl-analyze conversation /path/to/conversation.jsonl

# Or directly
ruby scripts/sfl_analysis/templates/conversation_analysis_template.rb \
  /path/to/conversation.jsonl \
  ./output
```

### 3. Check Results

Three files are generated in the output directory:

- `conversation_analysis.csv` - Turn-by-turn data for spreadsheet analysis
- `conversation_analysis.json` - Structured data for programmatic access
- `conversation_analysis.md` - Human-readable report with insights

## Input Format

Conversation files must be in JSONL format with this structure:

```json
{"name":"Alice","is_user":true,"send_date":"June 10, 2026 2:30pm","mes":"Hello, how are you?","extra":{}}
{"name":"Bob","is_user":false,"send_date":"June 10, 2026 2:31pm","mes":"I'm doing great, thanks!","extra":{}}
```

**Required fields**:
- `name` - Speaker name
- `send_date` - Timestamp (flexible format)
- `mes` - Message text

**Optional fields**:
- `is_user` - Boolean (ignored)
- `extra` - Additional metadata (ignored)

## Understanding the Output

### Tenor (Formality)

- **0.0-0.3**: Casual/informal (chat, DMs)
- **0.3-0.6**: Mixed (email, slack)
- **0.6-1.0**: Formal/technical (docs, papers)

### Modality (Certainty)

- **0.0-0.3**: Hedged/uncertain ("might", "could", "perhaps")
- **0.3-0.6**: Moderate ("should", "would", "likely")
- **0.6-1.0**: Certain/assertive ("will", "must", "definitely")

### Process Types

- **Material**: Actions ("run", "build", "deploy")
- **Mental**: Thoughts/feelings ("think", "want", "know")
- **Verbal**: Communication ("say", "tell", "ask")
- **Relational**: States/attributes ("is", "has", "becomes")
- **Behavioral**: Physiological ("laugh", "sigh", "breathe")
- **Existential**: Existence ("there is", "exists")

## Circuit Breaker Defaults

If Pass 2 (LLM annotation) fails or isn't configured, the pipeline uses safe defaults:

- Tenor: 0.5 (mixed formality)
- Modality: 0.5 (moderate certainty)
- Mood: "declarative"
- Attitude: "neutral"

This allows Pass 1 (process types, participants) to complete even without LLM access.

## Troubleshooting

### "No API key found"

Set the appropriate API key in `.env`:
```bash
OPENAI_API_KEY=sk-your-key-here
```

### "Circuit breaker open"

The LLM provider is failing. Check:
1. API key is correct
2. Provider is reachable
3. You have API credits

### All tenor values are 0.5

Pass 2 is using circuit breaker defaults. Verify:
1. `.env` file exists and is loaded
2. API key is set correctly
3. Provider string matches format (e.g., `openai/gpt-4o-mini`)

### Database connection error

Update `DATABASE_URL` in `.env`:
```bash
# Default (Unix socket)
DATABASE_URL=postgresql:///sfl_compiler_dev

# With host/port
DATABASE_URL=postgresql://user@localhost:5432/sfl_compiler_dev
```

## Advanced Usage

### Batch Processing

Process multiple conversations:

```bash
for file in conversations/*.jsonl; do
  ruby scripts/sfl_analysis/templates/conversation_analysis_template.rb \
    "$file" \
    "./output/$(basename "$file" .jsonl)"
done
```

### Custom Providers

Use any DSPy-compatible provider:

```bash
# Groq
DSPY_PROVIDER=groq/llama-3.1-70b-versatile
GROQ_API_KEY=your-key

# Together AI
DSPY_PROVIDER=together/meta-llama/Meta-Llama-3.1-70B-Instruct-Turbo
TOGETHER_API_KEY=your-key
```

### Pass 1 Only (No LLM)

Skip Pass 2 to avoid LLM costs:

```ruby
# In conversation_analysis_template.rb
pipeline = SFL::Compiler::Pipeline.new(db: @db, skip_pass_two: true)
```

This still extracts process types and participants but uses circuit breaker defaults for tenor/modality.
