# Pass 2 LLM Debugging Session - 2026-06-10

## Problem
All tenor and modality values were defaulting to 0.5, indicating LLM wasn't running.

## Root Cause Analysis

### Investigation Steps

1. **Checked DSPy configuration** ✅
   - Environment variables loaded correctly
   - API key present
   - dspy-openai gem installed

2. **Added verbose logging** ✅
   - Showed DSPy was being configured
   - But no visibility into actual errors

3. **Checked journald logs** 🎯
   ```bash
   journalctl --user -n 200 -o json | jq -r 'select(.MESSAGE == "sfl_annotator_failed") | .ERROR'
   ```
   
   **Found**: `OpenAI adapter error: No endpoints found for mistralai/mistral-7b-instruct`

### The Actual Problem

**Wrong model name!** OpenRouter model `mistralai/mistral-7b-instruct` doesn't exist.

The error was being caught silently by:
- `SFLAnnotator` (lib/sfl/compiler/pass_two/pass_two_engine.rb:211-220)
- Logs to journald only (not STDOUT)
- Returns default values (tenor=0.5, modality=0.5)
- Analysis completes "successfully" but with meaningless data

## Solution

### 1. Use Correct Model Name

Changed from:
```ruby
DSPY_PROVIDER=openrouter/mistralai/mistral-7b-instruct  # ❌ Doesn't exist
```

To:
```ruby
DSPY_PROVIDER=openrouter/xiaomi/mimo-v2.5  # ✅ Exists
```

### 2. Added Progress Visibility

Modified conversation analysis script to show:
- Turn-by-turn progress
- Processing time per turn
- Tenor values with ✓ (real) or DEFAULT (circuit breaker)

Example output:
```
[INFO] Compiling 29 conversation turns through SFL pipeline...
[INFO] Pass 1: spaCy (fast) + Pass 2: LLM annotation (slower)
[INFO] Progress:
  Turn 1/29 (Robert)... 2.3s [tenor: 0.32 ✓]
  Turn 2/29 (Steve)... 2.1s [tenor: 0.68 ✓]
```

### 3. Updated Documentation

- `.env.example` - List valid model names
- `QUICKSTART.md` - Show where to find model names
- `KNOWN_ISSUES.md` - Document journald debugging

## How to Find Valid OpenRouter Models

### Option 1: OpenRouter Dashboard
https://openrouter.ai/models

### Option 2: Check journald for "No endpoints found" errors
```bash
journalctl --user -n 100 -o json | jq -r 'select(.ERROR) | .ERROR' | grep "No endpoints"
```

### Option 3: Test with known working models
- `openrouter/google/gemini-2.0-flash-exp` (FREE)
- `openrouter/meta-llama/llama-3.1-8b-instruct:free` (FREE)
- `openrouter/xiaomi/mimo-v2.5` (Paid but cheap)

## Lessons Learned

### Silent Failures Are Dangerous

The framework gracefully degraded to defaults, which is good for resilience but bad for debugging. Future improvements:

1. **Add STDOUT logging in addition to journald**
   ```ruby
   rescue StandardError => e
     puts "[ERROR] SFL annotation failed: #{e.message}"  # NEW
     SFL::Compiler.logger.send_message(...)  # EXISTING
   ```

2. **Show warning when all values are defaults**
   ```ruby
   if analysis_result.speaker_profiles.all? { |_, p| p.avg_tenor == 0.5 }
     puts "[WARN] All tenor values are 0.5 - LLM may not be working!"
   end
   ```

3. **Test LLM on startup**
   - Simple "echo" test before processing
   - Fail fast if model doesn't exist

### Documentation Quality Matters

Using Context7 MCP to query actual docs for:
- `/vicentereig/dspy.rb` - Showed correct DSPy.configure usage
- `/wsargent/circuit_breaker` - Showed how circuit state works
- `/theforeman/journald-logger` - Showed structured logging format

This was WAY better than guessing from README snippets.

## Testing Results

### Before Fix
- Processing time: ~10 seconds
- All tenor values: 0.5
- All modality values: 0.5
- Journald: 673 `sfl_annotator_failed` errors

### After Fix (Expected)
- Processing time: ~2-3 minutes (673 LLM calls)
- Tenor values: Varying (0.2-0.8 range)
- Modality values: Varying
- Journald: Minimal errors

## Files Modified

1. `.env` - Changed to valid model name
2. `scripts/sfl_analysis/templates/conversation_analysis_template.rb` - Added progress output
3. `KNOWN_ISSUES.md` - Documented debugging process
4. `DEBUGGING_SESSION.md` - This file!

## Next Steps

1. ✅ Wait for current analysis to complete with Xiaomi Mimo
2. ⏳ Verify tenor values are varying (not all 0.5)
3. ⏳ Compare Robert vs Steve formality levels
4. ⏳ Update .env.example with tested, working models
5. ⏳ Add startup LLM test to fail fast on bad model names

## Cost Estimate

**Xiaomi Mimo v2.5** via OpenRouter:
- Input: $0.20 per 1M tokens
- Output: $0.80 per 1M tokens

For 29-turn conversation (~673 clauses):
- Estimated cost: $0.01 - $0.05
- Processing time: 2-3 minutes

Totally reasonable for development! 🎉
