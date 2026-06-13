# Known Issues

## Pass 2 LLM Integration

**Status**: 🔴 **WAS: Circuit breaker activating silently** → ✅ **FIXED: Visual error signal added**

**Original Symptoms** (pre-fix):
- All tenor values = 0.5
- All modality values = 0.5  
- Mood always "declarative"
- Analysis completes quickly (~10 seconds instead of expected 1-2 minutes)
- No visible indication of failure on CLI

**What Was Fixed** (2026-06-11):

**Root Cause**: The `SFLAnnotator#call` method caught ALL `StandardError` exceptions from `DSPy::ChainOfThought` and silently returned default values. The actual LLM errors were only logged to journald (`journalctl`), invisible on CLI.

**Changes** (`lib/sfl/compiler/pass_two/pass_two_engine.rb`):
1. Removed the `rescue StandardError` from `SFLAnnotator#call` — DSPy errors now propagate up normally
2. Added a `rescue StandardError => e` in `annotate_interpersonal` (the caller) that:
   - Logs to `$stderr` with a visible `[WARN]` message
   - Logs to journald (preserved)
   - Returns default interpersonal values (graceful degradation preserved)
3. Added `log_and_warn` helper to eliminate code duplication
4. Added `require "circuit_breaker"` (missing dependency)

**What Pass 2 Still Does If LLM Fails**:
- Returns `AnnotatedClause` with Pass 1 data intact (syntactic + ideational)
- Sets defaults for interpersonal: modality=0.5, tenor=0.5, mood=declarative
- Writes a visible warning to STDERR: `[WARN] Pass 2 (clause-xxx): DSPy annotation failed: <message>`
- Logs error details to journald for post-mortem

**To Debug Pass 2 Now**:
```bash
# Run analysis — errors visible directly in terminal output
bundle exec ruby scripts/parse_metacognitive_coprocessor.rb

# Or for detailed journald logs
journalctl -f | grep sfl_annotator

# Test with a simple LLM call through DSPy
bundle exec ruby -e '
require "dspy"
DSPy.configure { |c| c.lm = DSPy::LM.new("openrouter/mistralai/mistral-7b-instruct", api_key: ENV["OPENROUTER_API_KEY"]) }
puts DSPy::ChainOfThought.new(DSPy::Signature).call(text: "This works").to_h
'
```

**Confirmed Working** (unchanged):
- ✅ Environment variables loaded from `.env`
- ✅ DSPy configured with correct provider string
- ✅ OpenRouter API key present and formatted correctly
- ✅ dspy-openai gem installed
- ✅ Pass 1 (spaCy) working perfectly (673 clauses analyzed)
- ✅ Process types extracted correctly
- ✅ Speaker profiles built
- ✅ All formatters generating output
- ✅ Error signal now visible on CLI (no more silent failure)

## Installation Notes

**Tested Configuration**:
- Ruby 3.4.0
- PostgreSQL with pgvector
- spaCy en_core_web_sm
- Fedora Linux 43

**Dependencies Confirmed Working**:
- journald-logger ✅
- dspy ✅
- dspy-openai ✅
- ruby-spacy ✅
- pg, pgvector ✅
- All analysis modules ✅
- All formatters ✅
