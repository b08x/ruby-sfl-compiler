# Known Issues

## Pass 2 LLM Integration

**Status**: Circuit breaker activating silently

**Symptoms**:
- All tenor values = 0.5
- All modality values = 0.5  
- Mood always "declarative"
- Analysis completes quickly (~10 seconds instead of expected 1-2 minutes)

**Confirmed Working**:
- ✅ Environment variables loaded from `.env`
- ✅ DSPy configured with correct provider string
- ✅ OpenRouter API key present and formatted correctly
- ✅ dspy-openai gem installed
- ✅ Pass 1 (spaCy) working perfectly (673 clauses analyzed)
- ✅ Process types extracted correctly
- ✅ Speaker profiles built
- ✅ All formatters generating output

**Likely Causes**:
1. DSPy signature mismatch - LLM might not be returning expected JSON structure
2. Circuit breaker swallowing errors silently - no error logging visible
3. OpenRouter rate limiting or model compatibility issue
4. DSPy-openai adapter needs different configuration for OpenRouter

**Next Steps to Debug**:
1. Add verbose logging to PassTwoEngine to see actual LLM responses
2. Test with simpler DSPy signature (fewer output fields)
3. Try native OpenAI provider with gpt-4o-mini to isolate OpenRouter
4. Check journald logs for Pass 2 errors: `journalctl -f | grep sfl-compiler`
5. Add error logging before circuit breaker catches them

**Workaround**:
The framework is fully functional with Pass 1 only. You still get:
- Process type classification (material, mental, verbal, relational)
- Participant extraction
- Speaker turn analysis
- Process type distribution

Pass 2 (LLM tenor/modality) can be debugged independently without breaking the core pipeline.

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
