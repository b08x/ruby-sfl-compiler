# SFL Compiler Quick Start

Get up and running in 5 minutes with **FREE** LLM access!

## Option 1: OpenRouter (Recommended) 🚀

**Why?** One API key gives you access to dozens of models, including free tier options.

1. **Get your free API key**:
   - Go to https://openrouter.ai/
   - Sign up (free)
   - Get your API key from https://openrouter.ai/keys

2. **Add to `.env`**:
   ```bash
   OPENROUTER_API_KEY=sk-or-v1-YOUR-KEY-HERE
   DSPY_PROVIDER=openrouter/google/gemini-2.0-flash-exp  # FREE!
   ```

3. **Run analysis**:
   ```bash
   bundle exec sfl-analyze conversation /path/to/conversation.jsonl
   ```

**Free tier models on OpenRouter**:
- `openrouter/google/gemini-2.0-flash-exp` (FREE, fast)
- `openrouter/meta-llama/llama-3.1-8b-instruct` (FREE, very fast)

**Paid but cheap**:
- `openrouter/mistralai/mistral-7b-instruct` (~$0.06 per 1M tokens)
- `openrouter/mistralai/mixtral-8x7b-instruct` (~$0.24 per 1M tokens)

## Option 2: Google Gemini (Native) ⚡

**Why?** Direct access to Google's models with generous free tier.

1. **Get your free API key**:
   - Go to https://aistudio.google.com/app/apikey
   - Create API key (free tier: 60 requests/minute)

2. **Add to `.env`**:
   ```bash
   GOOGLE_API_KEY=YOUR-KEY-HERE
   DSPY_PROVIDER=google/gemini-2.0-flash-exp
   ```

3. **Run analysis**:
   ```bash
   bundle exec sfl-analyze conversation /path/to/conversation.jsonl
   ```

## Option 3: Local Models (No API Key) 🏠

**Why?** Completely free, runs on your hardware.

1. **Install Ollama**:
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   ```

2. **Pull a model**:
   ```bash
   ollama pull llama3.1:8b
   ```

3. **Configure `.env`**:
   ```bash
   DSPY_PROVIDER=ollama/llama3.1:8b
   # No API key needed!
   ```

4. **Run analysis**:
   ```bash
   bundle exec sfl-analyze conversation /path/to/conversation.jsonl
   ```

## Test Your Setup

Run the sample conversation:

```bash
bundle exec sfl-analyze conversation /home/b08x/Workspace/Datasets/steve-oliver-2025-08-29@13h25m38s.jsonl
```

Check the output:

```bash
cat sfl_output/conversation_analysis.md
```

**Success indicators**:
- ✅ Tenor values vary (not all 0.5)
- ✅ Modality values vary (not all 0.5)
- ✅ Speaker profiles show differences

**Still seeing 0.5 everywhere?** The LLM isn't running. Check:
1. API key is set correctly in `.env`
2. Provider string matches examples above
3. `.env` file is in the project root

## Cost Estimates

**For the 29-turn steve-oliver conversation**:

| Provider | Cost | Speed |
|----------|------|-------|
| OpenRouter Gemini 2.0 Flash | **FREE** | ~30 sec |
| OpenRouter Mistral 7B | $0.001 | ~15 sec |
| Google Gemini (native) | **FREE** | ~30 sec |
| Ollama Llama 3.1 | **FREE** | ~2 min |

## Next Steps

Once you verify it's working with real LLM values:

1. **Batch process conversations**:
   ```bash
   for convo in conversations/*.jsonl; do
     bundle exec sfl-analyze conversation "$convo"
   done
   ```

2. **Try different providers** to compare tenor/modality annotations

3. **Explore the outputs**:
   - CSV for spreadsheet analysis
   - JSON for programmatic access
   - Markdown for human reading

4. **Check the documentation**:
   - `USAGE.md` - Complete usage guide
   - `README.md` - Architecture and API
   - `docs/knowledge-base.md` - Framework details

## Troubleshooting

**"Invalid API key"**
- Check the key is pasted correctly (no extra spaces)
- For OpenRouter: key starts with `sk-or-v1-`
- For Google: key is alphanumeric

**"All values still 0.5"**
- Verify `.env` file exists: `ls -la .env`
- Check it's being loaded: Add `puts "PROVIDER: #{ENV['DSPY_PROVIDER']}"` at top of script
- Try a different provider

**"Rate limit exceeded"**
- Use a slower model
- Add delays between turns (not implemented yet)
- Switch to Ollama for unlimited local inference

**"Model not found"**
- Check provider string format
- For OpenRouter: must start with `openrouter/`
- For Gemini: use `google/` or `openrouter/google/`

## Getting Help

If you're stuck:
1. Check the error message carefully
2. Verify your `.env` configuration
3. Try the simplest option (OpenRouter Gemini free tier)
4. Check GitHub issues at the sfl-compiler repo

Happy analyzing! 🎉
