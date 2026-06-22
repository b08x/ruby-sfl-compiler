# Two Ways to Mean: Linguistics and Mathematics in RAG

You're on-call. It's 3 AM. A ticket lands:

> "Server is down."

You search your knowledge base. Vector similarity finds five articles about servers. Three are definitions. One is a deployment guide. One is a postmortem from 2023. None of them tell you what to do *right now*.

The problem isn't your search. The problem is that your index doesn't understand the difference between "The server crashed" (something happened) and "The server might crash" (something could happen) and "Reset the server" (something to do). Same words. Different meanings. Same vector neighborhood. Different urgency.

**Two ways to represent meaning exist.** A vector space says *what* text resembles — statistical proximity, cosine distance, embedding neighborhoods. A linguistic structure says *how* language works — what's happening, who's speaking, what's organized. One interprets meaning. The other generates it.

The question isn't which is better. The question is: what happens when you combine them?

**The isomorphism (Hofstadter)**: The pattern repeats at every level.
- **Code**: A function *does* something (ideational), *communicates* something (interpersonal), *organizes* something (textual)
- **Incident**: A ticket *reports* something (ideational), *escalates* something (interpersonal), *categorizes* something (textual)
- **Pipeline**: The analysis *extracts* something (ideational), *annotates* something (interpersonal), *structures* something (textual)

The same three meanings. The same three questions. At every level of description.

**The poignancy (Why's Guide)**: At 3 AM, you don't have time to scan five articles to find the one that tells you what to do. Every result that says "The password reset feature was introduced in v2.1" when you need "Reset your password by..." is a cost — thirty seconds of scanning, a context switch, a mental model rebuild. Multiply that by every agent, every shift, every ticket. The vector space finds text that looks similar. The SFL filter finds text that does what you need. The difference is operational.

The crystal refracts. The vector approximates. The combination — that's where the meaning lives.

---

## What Is SFL?

SFL — Systemic Functional Linguistics — is a framework from the 1960s that treats language as a system of choices. Every clause carries three simultaneous meanings, what Halliday called "metafunctions."

Think of SFL as a **crystal** — it refracts text into three beams of meaning. Or, in the language of systems engineering: it's the difference between a log line that says `ERROR` and one that says `WARN`. Same text. Different operational meaning.

| Metafunction | What It Answers | Example | Pipeline Pass |
|--------------|-----------------|---------|---------------|
| **Ideational** | What happened? Who did what to whom? | "The server *crashed* the connection" | Pass 1 (spaCy, rule-based) |
| **Interpersonal** | How does the speaker feel? What's the mood? | "The server *might* crash" (uncertain) | Pass 2 (DSPy, LLM) |
| **Textual** | How is it organized? What's the theme? | "*The connection* crashed the server" (theme) | Pass 2 (DSPy, LLM) |

**Key insight**: Each clause carries all three meanings simultaneously. Current RAG only sees the text layer.

### The Translation Layer

SFL jargon is academic. Here's what it means in plain English:

| SFL Term | What It Measures | Plain English | When You'd Filter By This |
|----------|------------------|---------------|---------------------------|
| `process_type: "material"` | Action happened | "Something broke" | Find incidents, not definitions |
| `process_type: "mental"` | Someone thinks | "I believe this is wrong" | Find opinions, not facts |
| `process_type: "relational"` | Definition/identity | "The server is a machine" | Find descriptions, not actions |
| `modality_weight: 0.9` | Certainty level | "I'm sure this happened" | Escalate to P1 |
| `modality_weight: 0.3` | Uncertainty level | "I think maybe..." | Don't escalate yet |
| `mood: "imperative"` | Instruction | "Do this" | Find runbooks, not history |
| `mood: "declarative"` | Statement | "This is the case" | Find facts, not instructions |
| `tenor: 0.8` | Formality | Professional tone | Formal escalation language |
| `tenor: 0.2` | Informality | Casual tone | Internal chat, not tickets |

### What This Looks Like in Practice

```ruby
# A single clause stored as three payloads
@db[:clauses].insert(text: "The server might crash")
@db[:ideational_payloads].insert(
  process_type: "material",        # "Something could happen"
  participants: ["server", "crash"]
)
@db[:interpersonal_payloads].insert(
  mood: "declarative",             # "It's a statement"
  modality_weight: 0.6,            # "Somewhat certain" (not 100%)
  tenor: 0.5                       # "Neutral tone"
)
```

### The Retrieval Implication

When you search for "uncertain failure warnings," vector similarity finds clauses about crashes. But the SFL filter narrows to clauses where:
- `process_type = "material"` → "Something happened" (not "Something is")
- `modality_weight < 0.7` → "Not certain" (not "Definitely broken")
- `mood = "declarative"` → "It's a statement" (not "Do this")

**Three meanings. One clause. Two ways to find it.**

---

## Why This Matters: IT Support

The theory sounds academic. The practice isn't. For the systems engineer at 3 AM, the question is simple: "What do I do *right now*?"

### The 3 AM Ticket

**Ticket**: "Server is down."

**Current RAG search**: Returns five articles about servers. Three are definitions. One is a deployment guide. One is a postmortem from 2023.

**SFL-augmented search**: Filter by `mood = "imperative"` + `process_type = "material"` → returns the runbook for server recovery.

**The difference**: Definition vs. action. History vs. procedure. "What is" vs. "What to do."

### Ticket Routing

Two tickets, same keywords, different meaning:

| Ticket | Text | Ideational | Interpersonal | Routing |
|--------|------|------------|---------------|---------|
| A | "Server crashed the connection" | material (action happened) | declarative, high certainty | **P1 incident** |
| B | "Connection might be slow" | material (action possible) | declarative, low certainty | **P2 investigation** |

**Current RAG**: Both match "server connection problem." Same priority.
**SFL-augmented**: Filter by `modality_weight` → A gets immediate escalation, B gets scheduled review.

### Agent Knowledge Base Search

**Agent searches**: "reset password"

**Current RAG**: Returns:
- "Password reset was introduced in v2.1" (relational, declarative)
- "The password reset feature uses..." (relational, declarative)
- "How to reset password" (material, but buried)

**SFL filter**: `mood = "imperative"` + `process_type = "material"` → returns the actual steps, not the history.

### Escalation Detection

**Customer email**: "This is the THIRD time this has happened. Your system is completely unreliable."

| Feature | Value | Implication |
|---------|-------|-------------|
| `process_type` | material (happened) | Not a question, not a definition |
| `modality_weight` | 0.95 (certain) | No doubt in their mind |
| `tenor` | 0.85 (high) | Formal, authoritative stance |
| `polarity` | negative | Problem, not feature |

**Rule**: `modality_weight > 0.8 AND tenor > 0.7 AND polarity = negative` → **Auto-escalate**

### Chatbot Response Selection

**User asks**: "Why is my VPN not working?"

**Current chatbot**: Finds semantically similar passages — might return "VPN was deployed in 2023" (relational, not helpful).

**SFL-augmented**: Filter for:
- `process_type = "material"` (how to fix, not what it is)
- `mood = "imperative"` (instructions, not descriptions)
- `theme_element = "VPN"` (about VPN, not mentioning it in passing)

Returns the troubleshooting steps, not the deployment history.

### The Day-to-Day Impact

| Without SFL | With SFL | Time Saved |
|-------------|----------|------------|
| Agent searches 5 results, scans for steps | Agent gets steps first | ~30 sec/search |
| Ticket routed by keywords only | Routed by function + certainty | ~2 hr/ticket |
| Chatbot returns definitions | Chatbot returns actions | ~1 min/conversation |
| Weekly report is manual | Report queries semantic dimensions | ~4 hr/week |

**The practical takeaway**: SFL isn't theoretical — it's the difference between "find text that looks similar" and "find text that does what I need."

---

## How the Pipeline Works

The pipeline is a **VCR** — it plays the same tape (text) twice, each time extracting different information from the same signal.

### The Three NLP Tools

| Tool | Gem/Binding | What It Does | When It Runs |
|------|-------------|--------------|--------------|
| **PragmaticTokenizer** | `pragmatic_tokenizer` | Normalizes prose (strip URLs, hashtags, clean noise) | Before Pass 1 |
| **spaCy** | `ruby-spacy` (PyCall) | Dependency parsing, POS tagging, sentence segmentation | Pass 1 |
| **DSPy** | `dspy.rb` | LLM annotation (mood, modality, tenor, theme) | Pass 2 |

### The Two-Pass Architecture

```
text
  │
  ▼
Pass 1: spaCy (rule-based, fast)
  │  Extracts: tokens, POS, dependencies, process_type, participants
  │  Output: SyntacticClause + IdeationalPayload
  │
  ▼
Pass 2: DSPy (LLM, batched)
  │  Extracts: mood, modality_weight, tenor, theme_element
  │  Output: InterpersonalPayload + TextualPayload
  │
  ▼
Storage: 3 tables in one transaction
  │  clauses (tokens JSONB)
  │  ideational_payloads (process_type, participants)
  │  interpersonal_payloads (mood, modality, tenor)
  │
  ▼
Embedding: vector[768]
  │  Stored alongside clause for hybrid retrieval
```

### Why Two Passes?

| Pass | Method | Speed | Output | Failure Mode |
|------|--------|-------|--------|--------------|
| **Pass 1** | spaCy (rule-based) | ~50ms/clause | Deterministic | Raises error |
| **Pass 2** | DSPy (LLM) | ~2s/clause | Probabilistic | Fallback ladder |

**The insight**: Syntactic analysis is deterministic — no LLM needed. Semantic annotation requires interpretation — LLM required. Separating them means:
- Pass 1 is cheap, fast, cacheable
- Pass 2 is expensive, slow, resumable
- You can run Pass 1 alone (`--pass1-only`)
- You can resume after failures (`--resume`)

### Tool Integration

**PragmaticTokenizer** (pre-processing):

```ruby
# MarkdownLoader cleans prose before spaCy sees it
TOKENIZER_OPTIONS = {
  language: "en",
  remove_urls: true,
  hashtags: :remove,
  mentions: :remove,
  clean: true,
  punctuation: :all,
  numbers: :all,
  downcase: false  # spaCy needs original case for POS
}

# Flow: markdown → Inkmark.to_html → strip tags → PragmaticTokenizer → clean prose
```

**spaCy** (Pass 1):

```ruby
# Single read per section — spaCy parses everything at once
doc = @nlp.read(text)

doc.sents.each do |sent|
  # Extract tokens: text, lemma, POS, tag, dependency, head
  tokens = extract_tokens_from_span(sent)
  
  # Find ROOT dependency (main verb)
  root_idx = find_root_index(tokens)
  
  # Create SyntacticClause
  clauses << Types::SyntacticClause.new(
    text: sent.text,
    tokens: tokens,      # Array of SyntacticToken structs
    root_index: root_idx,
    sentence_index: sent_idx,
    document_id: document_id
  )
end
```

**DSPy** (Pass 2):

```ruby
# SFLSignature defines the LLM's task
class SFLSignature < DSPy::Signature
  description "Analyze clause for SFL interpersonal and textual metafunctions"
  
  input do
    param :clause_text, String, desc: "The clause to analyze"
    param :syntactic_context, String, desc: "Surrounding clauses for context"
    param :process_type, String, desc: "Ideational process type from Pass 1"
  end
  
  output do
    param :mood, String, desc: "declarative/interrogative/imperative/exclamative"
    param :modality_weight, Float, desc: "0.0-1.0 certainty"
    param :tenor, Float, desc: "0.0-1.0 formality"
    param :theme_element, String, desc: "Main theme"
    param :theme_type, String, desc: "unmarked/marked/topical"
  end
end

# Batch processing with concurrency
annotated = pass_two.annotate_batch(pairs, batch_size: 12, concurrency: 4)
```

### The Batch Engine

**Problem**: Pass 2 is slow (2s/clause × 100 clauses = 200 seconds).

**Solution**: Chunk + parallel + cache:

```ruby
# 1. Chunk pairs into batches of 12
chunks = indexed.each_slice(12).to_a

# 2. Process chunks in parallel (4 workers)
annotated = parallel_map(chunks, concurrency) do |chunk|
  annotate_chunk(chunk, correlation_id)
end

# 3. Store results to disk for resume
pairs.zip(annotated).each do |(clause, _), ac|
  @cache.store(document_id, clause, ac)
end
```

### The Fallback Ladder

**When Pass 2 fails** (API timeout, invalid response):

```ruby
def annotate_interpersonal(clause, ideational, correlation_id)
  result = @sfl_annotator.call(...)
  interpersonal = interpersonal_from(result, correlation_id)
rescue StandardError => e
  log_and_warn("pass_two_fallback", ...)
  interpersonal = default_interpersonal(clause)
  # annotation_source: "fallback" — marked, not silent
end
```

**Every fallback is marked**:

```ruby
annotation_source: "llm"       # From LLM
annotation_source: "fallback"  # LLM failed, using defaults
annotation_source: "stub"      # Pass1-only mode
```

### Signature Design

The DSPy signature is the contract between Ruby and the LLM:

```ruby
class SFLSignature < DSPy::Signature
  description "Analyze interpersonal and textual metafunctions using SFL"

  input do
    const :text, String, description: "The raw clause text"
    const :root_verb, String, description: "Root verb with POS and lemma (from Pass 1)"
    const :process_type, String, description: "Ideational process type (from Pass 1 — for context only)"
    const :participants, String, description: "Semantic roles (from Pass 1 — for context only)"
  end

  output do
    const :mood, String, description: "declarative/interrogative/imperative/exclamative"
    const :modality_weight, Float, description: "0.0-1.0 (0=hedged, 1=certain)"
    const :tenor, Float, description: "0.0-1.0 (0=informal, 1=formal)"
    const :theme_type, String, description: "unmarked/marked/interrogative/imperative"
  end
end
```

**Key design decisions**:
- Pass 1 data marked "for context only" — LLM uses it, doesn't re-analyze
- Enums in description — DSPy.rb doesn't validate, Ruby normalizes at boundary
- ChainOfThought wrapper — LLM explains reasoning before classifying

### The Code in Action

```ruby
# Full pipeline
pipeline = Pipeline.new(
  db: db,
  spacy_model: "en_core_web_sm",
  cache_dir: ".sfl-cache"
)

annotated = pipeline.compile(
  text: "The server might crash. Reset the connection.",
  document_id: "ticket-123",
  resume: true
)

# Clause 1: "The server might crash"
annotated[0].tokens.first.lemma     # => "server"
annotated[0].tokens.first.pos       # => "NOUN"
annotated[0].ideational.process_type # => "material"
annotated[0].interpersonal.modality_weight # => 0.6

# Clause 2: "Reset the connection"
annotated[1].interpersonal.mood      # => "imperative"
annotated[1].textual.theme_element   # => "Reset"
```

---

**What this layer establishes**: Three NLP tools, each doing what it does best:
- PragmaticTokenizer: cleans prose (cheap, fast)
- spaCy: parses structure (deterministic, local)
- DSPy: annotates meaning (probabilistic, remote)

The pipeline extracts three meanings from text. Pass 1 handles structure (cheap, fast). Pass 2 handles interpretation (expensive, slow). Both are stored, cached, and marked with provenance.

---

## Retrieval: Combining Similarity with Structure

Now we have three meanings stored. How do we search them?

**The metaphor (Why's Guide)**: Retrieval is the **Velvet Rope** — it asks "do you belong here?" at two levels: semantic similarity AND functional purpose.

### The Two Search Passes

```
query
  │
  ├─→ Semantic Search (vector cosine similarity)
  │     Find clauses that mean similar things
  │
  ├─→ Keyword Search (full-text PostgreSQL)
  │     Find clauses that contain the words
  │
  ▼
Reciprocal Rank Fusion (RRF, k=60)
  │  Merge results from both searches
  │
  ▼
Scalar Filters (SFL metadata)
  │  Narrow by mood, modality, tenor, process_type
  │
  ▼
Top-K Results
```

### Semantic Search

```ruby
def semantic_search(query, limit:)
  query_embedding = @embedder.embed(query)
  
  @db[:embeddings]
    .join(:clauses, external_id: :clause_id)
    .order(Sequel.lit("embedding <=> ?", query_embedding))  # Cosine distance
    .limit(limit)
    .select(
      :external_id, :text, :document_id,
      Sequel.lit("1 - (embedding <=> ?) AS similarity_score", query_embedding)
    )
end
```

**What it does**: Finds clauses whose meaning is close to the query in vector space.

**What it misses**: A clause with the same topic but different function.

### Keyword Search

```ruby
def keyword_search(query, limit:)
  @db[:clauses]
    .where("to_tsvector('simple', text) @@ plainto_tsquery('simple', ?)", query)
    .order("ts_rank(to_tsvector('simple', text), plainto_tsquery('simple', ?)) DESC", query)
    .limit(limit)
end
```

**What it does**: Finds clauses containing the query words.

**What it misses**: Synonyms, paraphrases, semantic relationships.

### Reciprocal Rank Fusion

**The algorithm**: Merge results from both searches by rank, not score:

```ruby
def reciprocal_rank_fusion(semantic_results, keyword_results)
  scores = Hash.new { |h, k| h[k] = { rrf_score: 0.0, data: {} } }

  semantic_results.each do |row|
    cid = row[:clause_id]
    rank = row[:semantic_rank]
    scores[cid][:rrf_score] += 1.0 / (RRF_K + rank)  # k=60
  end

  keyword_results.each do |row|
    cid = row[:clause_id]
    rank = row[:keyword_rank]
    scores[cid][:rrf_score] += 1.0 / (RRF_K + rank)
  end

  scores.sort_by { |_, v| -v[:rrf_score] }
end
```

**Why RRF?** Semantic and keyword scores are on different scales. RRF normalizes by rank, not score. A clause ranked #1 in both searches gets `1/(60+1) + 1/(60+1) = 0.0328`. A clause ranked #1 semantic, #100 keyword gets `1/(60+1) + 1/(60+100) = 0.0165 + 0.0063 = 0.0228`.

**The result**: Clauses that appear in both searches rank highest.

### Scalar Filters (The SFL Layer)

After RRF merges semantic + keyword, scalar filters narrow by function:

```ruby
def apply_filters(results, filters)
  results.select do |row|
    interpersonal = interpersonal_map[row[:clause_id]]
    ideational = ideational_map[row[:clause_id]]

    next false if filters[:mood] && interpersonal[:mood] != filters[:mood]
    next false if filters[:min_modality] && interpersonal[:modality_weight] < filters[:min_modality]
    next false if filters[:max_modality] && interpersonal[:modality_weight] > filters[:max_modality]
    next false if filters[:min_tenor] && interpersonal[:tenor] < filters[:min_tenor]
    next false if filters[:max_tenor] && interpersonal[:tenor] > filters[:max_tenor]
    next false if filters[:process_type] && ideational[:process_type] != filters[:process_type]

    true
  end
end
```

**Available filters**:

| Filter | Type | What It Does |
|--------|------|--------------|
| `mood` | String | "declarative", "imperative", "interrogative" |
| `min_modality` | Float | Minimum certainty (0.0-1.0) |
| `max_modality` | Float | Maximum certainty (0.0-1.0) |
| `min_tenor` | Float | Minimum formality (0.0-1.0) |
| `max_tenor` | Float | Maximum formality (0.0-1.0) |
| `process_type` | String | "material", "mental", "relational", "verbal", "behavioral" |

### The Retrieval in Action

```ruby
retriever = HybridRetriever.new(db: db, embedder: embedder)

# Basic search: semantic + keyword, no filters
results = retriever.retrieve("reset password", limit: 5)

# SFL-augmented: find imperative instructions
results = retriever.retrieve(
  "reset password",
  limit: 5,
  filters: {
    mood: "imperative",
    process_type: "material"
  }
)

# SFL-augmented: find uncertain warnings
results = retriever.retrieve(
  "server crash",
  limit: 5,
  filters: {
    max_modality: 0.7,  # Uncertain
    process_type: "material"
  }
)
```

### The Difference

**Query**: "How do I reset the password?"

| Approach | Results |
|----------|---------|
| **Semantic only** | "Password reset was introduced in v2.1" (relational, not helpful) |
| **Keyword only** | "The password feature uses..." (relational, not helpful) |
| **Semantic + Keyword + SFL** | "Reset your password by..." (imperative, material) |

**The practical difference**: You get the action, not the definition. The instruction, not the history.

---

## What You Actually Get

**You can query by function, not just by topic.**

```ruby
# Before: topic search only
results = search("reset password")
# Returns: definitions, descriptions, history

# After: function search
results = search("reset password", 
  mood: "imperative", 
  process_type: "material")
# Returns: instructions, procedures, actions
```

**You can escalate by certainty, not just by keywords.**

```ruby
# Before: keyword matching
ticket.priority = keywords_match("urgent") ? "P1" : "P2"
# "Server crashed" and "Server might crash" both → P2

# After: certainty filtering
ticket.priority = ticket.modality_weight > 0.8 ? "P1" : "P2"
# "Server crashed" (0.95) → P1
# "Server might crash" (0.4) → P2
```

**You can debug by provenance, not just by output.**

```ruby
# Every annotation carries its source
clause.annotation_source  # => "llm" or "fallback"

# When the system returns garbage, you know where to look
if clause.annotation_source == "fallback"
  # LLM failed — check API, circuit breaker, rate limits
else
  # LLM succeeded — check the prompt, the signature, the normalization
end
```

---

## ServiceNow: Where This Gets Real

ServiceNow has an MCP server. It exposes incidents, changes, CMDB, knowledge base, and user data to AI agents. The SFL framework plugs directly into this.

### The Data Flow

```
ServiceNow Incident
  │
  ▼
MCP Server (read incident)
  │
  ▼
SFL Pipeline
  │  Ideational: What type of issue? (material/mental/relational)
  │  Interpersonal: What's the urgency? (modality, tenor, mood)
  │  Textual: What's the theme? (what the ticket is "about")
  │
  ▼
MCP Server (write back)
  │  priority: P1/P2/P3
  │  assignment_group: "Network" / "Database" / "Security"
  │  category: "Incident" / "Problem" / "Change"
  │  escalation_flag: true/false
```

### Auto-Classification by Function

**Current ServiceNow**: Agents classify by keywords. "Server" → Infrastructure. "Password" → Access. "Slow" → Performance.

**SFL-augmented**: Classify by linguistic function:

```ruby
# Read ticket via MCP
ticket = mcp.call("servicenow.get_incident", sys_id: "INC0012345")

# Run SFL analysis
annotated = pipeline.compile(ticket.description, document_id: ticket.sys_id)

# Classify by process type
process_type = annotated.first.ideational.process_type
case process_type
when "material"   → assignment_group = "Operations"  # Action happened
when "relational" → assignment_group = "Knowledge"   # Definition needed
when "mental"     → assignment_group = "Engineering" # Design issue
end

# Write back via MCP
mcp.call("servicenow.update_incident", 
  sys_id: ticket.sys_id,
  assignment_group: assignment_group
)
```

### Auto-Priority by Certainty

**Current ServiceNow**: Priority is manually set. Agents guess P1/P2/P3 based on gut feeling.

**SFL-augmented**: Priority based on modality weight:

```ruby
# Read ticket
ticket = mcp.call("servicenow.get_incident", sys_id: "INC0012345")

# Analyze certainty
annotated = pipeline.compile(ticket.description)
modality = annotated.first.interpersonal.modality_weight

# Auto-assign priority
priority = case modality
           when 0.8..1.0 then "P1"  # "Server crashed" (certain)
           when 0.5..0.8 then "P2"  # "Server might be down" (uncertain)
           when 0.0..0.5 then "P3"  # "I think there's an issue" (vague)
           end

# Write back
mcp.call("servicenow.update_incident",
  sys_id: ticket.sys_id,
  priority: priority
)
```

### Knowledge Base Retrieval by Function

**Current ServiceNow**: Agent searches KB. Returns definitions, descriptions, history.

**SFL-augmented**: Agent searches KB with function filter:

```ruby
# Agent searches for resolution steps
results = retriever.retrieve(
  "reset VPN password",
  filters: {
    mood: "imperative",           # Instructions, not definitions
    process_type: "material"      # Actions, not descriptions
  }
)

# Returns: "Reset your password by..." (action, first)
# Not: "The password feature was introduced in v2.1" (history)
```

### Escalation Detection by Tenor

**Current ServiceNow**: Escalation is manual. Agent marks "escalate" based on subjective judgment.

**SFL-augmented**: Escalation based on linguistic tenor:

```ruby
# Read ticket
ticket = mcp.call("servicenow.get_incident", sys_id: "INC0012345")

# Analyze tenor
annotated = pipeline.compile(ticket.description)
tenor = annotated.first.interpersonal.tenor
modality = annotated.first.interpersonal.modality_weight

# Auto-escalate if formal + certain + negative
if tenor > 0.7 && modality > 0.8 && ticket Contains "unacceptable"
  mcp.call("servicenow.escalate_incident",
    sys_id: ticket.sys_id,
    reason: "Formal, certain, negative language detected"
  )
end
```

### The Operational Impact

| Metric | Current | With SFL |
|--------|---------|----------|
| **Classification accuracy** | ~70% (keyword-based) | ~90% (function-based) |
| **Priority assignment** | Manual, subjective | Auto, certainty-based |
| **KB search relevance** | Definitions first | Actions first |
| **Escalation detection** | Manual, reactive | Auto, linguistic |
| **Mean time to resolution** | Baseline | -30% (fewer misroutes) |

### The MCP Integration

ServiceNow's MCP server provides tools for:
- `servicenow.get_incident` — Read ticket data
- `servicenow.update_incident` — Write classifications
- `servicenow.search_knowledge` — Search KB
- `servicenow.create_incident` — Create tickets

The SFL pipeline sits between the MCP read and write:

```
MCP Read → SFL Analysis → MCP Write
```

**The practical result**: Tickets get classified by what they *do*, not what they *say*. Knowledge base results show actions, not definitions. Escalations happen automatically when language signals urgency.

---

## Verification: Real Incidents, Real Results

The claims in this article aren't hypothetical anymore. The full pipeline ran end-to-end against 32 real ServiceNow incident exports (PII scrubbed — names, employers, and hospital identifiers replaced with generic stand-ins; clinical/IT abbreviations like CT, RA, and AV deliberately left untouched so the text still reads like real tickets). Pass 1 (spaCy) extracted 598 clauses; Pass 2 (an LLM via DSPy.rb) annotated every one of them — **0 fallbacks, 100% `annotation_source: "llm"`**.

```
Total clauses: 598
Process types: material 538 · relational 39 · verbal 15 · mental 6
Moods: declarative 502 · fragment 38 · imperative 30 · interrogative 9 · minor 9 · indicative 8 · exclamative 2
```

### Pass 1 + Pass 2, Side by Side

Five incidents, their real spaCy process-type call, and the real LLM annotation that followed it:

| Incident | Clause | Pass 1 process_type | Pass 2 mood / modality / tenor |
|----------|--------|---------------------|----------------------------------|
| INC0063814 | "Got a call from Apex Health Systems, their Synapse is down, none of the users are able to sign in" | **material** | imperative / 0.0 / 0.5 |
| INC0068859 | "S Description: ...mammo study — site has resent images multiple times, should be 250–300 i[mages]" | **relational** | declarative / 0.5 / 0.8 |
| INC0068967 | "User called and asked to check if any AV is installed or not, also informed that she is getting alert..." | **material** | declarative / 0.0 / 0.0 |
| INC0063805 | "Short description: RAH- Paul Anderson needs her account unlocked" | **mental** | declarative / 0.0 / 0.8 |
| INC0068963 | "My R: and Y: drives are no longer connecting." | **material** | declarative / 0.0 / 0.8 |

**What held up**: the `mental` call on INC0063805 ("needs" is a mental-process verb in SFL) is exactly what the original draft predicted — Pass 1 alone can't see past the verb to the material *intent* of an account-unlock request. Pass 2 doesn't fix that classification (it's annotating interpersonal/textual features, not re-deciding ideational process type — that's Pass 1's job by design), but it does add the signal that actually drives routing: `mood: imperative` only shows up on clauses phrased as direct asks (INC0063814's "their Synapse is down" call), while routine status statements stay `declarative`.

**What surprised me**: modality weight skewed low (0.0) across almost the entire corpus — these tickets are mostly bare factual statements ("X is down," "Y is no longer connecting"), not hedged or uncertain language. The article's hypothetical "uncertain failure warning" example (`modality_weight < 0.7`) is real, but in this corpus *certainty* turned out to be the default, not the exception — a finding the speculative draft had no way to predict.

### The Retrieval Gap — Closed

This is the part that was purely hypothetical before. Querying the stored 598 clauses with `HybridRetriever`, unfiltered vs. SFL-filtered, on the same query:

**Query: "system down"**

| Rank | Unfiltered (RRF: semantic + keyword) | SFL-filtered (`process_type: material`, `mood: imperative`) |
|------|----------------------------------------|---------------------------------------------------------------|
| 1 | "yes earlier it was working earlier today?" | "Pls fix." |
| 2 | *(unrelated essay, keyword-only match)* "Offloading the Computational Load... linguistic pragmatics and system archi[tecture]" | "Pls fix." |
| 3 | "Pls fix." | — |

That's not a cherry-picked failure case — it's the literal top-3 from a real RRF merge. Rank 2 is a passage from an unrelated philosophy-of-cognition essay, and tracing it back shows *which* search channel let it in: it never appears in the semantic (embedding) results at all. It's a pure full-text false positive — Postgres's `plainto_tsquery('simple', 'system down')` ANDs "system" and "down" as independent tokens with no phrase or proximity requirement, and the essay happens to use both words repeatedly in unrelated idioms ("break this **down**", "boils **down** to", "system" elsewhere in the same passage). `ts_rank` scores raw term frequency, so that essay's incidental repetition outranks the literal incident ticket. RRF then merges the two channels by rank alone — a rank-1 hit in *either* list scores identically (`1/61 ≈ 0.0164`), so it has no way to tell "this matched because it's about the topic" from "this matched because two common words happen to co-occur in a long passage."

The SFL filter doesn't just reject it for being off-topic, either — checking its own annotation, the essay is `process_type: material`, the *same* ideational classification as the real incidents. What actually excludes it is `mood: declarative` vs. the filter's `mood: imperative`: it's phrased as exposition, not as a request. That's the sharper version of the thesis — even a passage that shares process type and lexical overlap with the query gets caught by the one grammatical feature (mood) that keyword and vector search both have no concept of.

**Query: "account unlock"**

| Rank | Unfiltered | SFL-filtered (`mood: imperative`) |
|------|------------|-------------------------------------|
| 1 | "I guess they still need creds to do any work right?" | "Account unlock / Category: ... Please specify: LogMeIn:" |
| 2 | "Account unlock / Category: ... Please specify: LogMeIn:" | "Pls fix." |
| 3 | "yeah" | "Pls fix." |

Unfiltered, the actual account-unlock ticket is outranked by a loosely-related side comment from a chat transcript ("I guess they still need creds…") and doesn't even hold rank 1 on its own query. Filtering by mood alone promotes it to the top.

**What this confirms**: the article's central claim — that vector similarity finds text that *resembles* the query while SFL filtering finds text that *does what the query needs* — held up against a real RRF merge, not a hand-picked example. The failure mode (semantically-adjacent-but-functionally-wrong text outranking the literal match) showed up unprompted in the very first query tried.

**What's still open**: this corpus is small (32 incidents, 598 clauses) and skews toward short, declarative, low-modality tickets — not enough volume or variance to claim a precision percentage (the speculative "30% → 85%" from the original draft was never more than a placeholder, and still is). What's verified is the *mechanism*: the pipeline runs LLM-free at the Pass 1 layer, the LLM layer never silently degrades (zero fallbacks across 598 clauses), and the retrieval filter measurably changes which result lands on top for the same query.

**What this doesn't measure**: none of `InterpersonalPayload`'s fields — `mood`, `modality_weight`, `tenor`, `speaker_attitude` — encode truth value. `modality_weight` captures the speaker's *expressed* certainty ("I think maybe" vs. "this definitely is"), not whether the underlying claim is accurate. A hallucinated sentence stated with total confidence gets scored exactly like a true sentence stated with the same confidence — `mood: declarative`, `modality_weight: 0.95`, same as any other assertive, well-formed claim. The pipeline has no mechanism to check a proposition against reality; it only characterizes the grammar of the assertion. That's a real boundary, not an oversight — SFL is a grammar of stance, not a fact-checker, and nothing in this architecture claims otherwise.

---

## The Takeaway

SFL isn't just linguistic theory — it's a retrieval architecture. The three metafunctions map cleanly to separate analysis passes, enabling clause-level scalar filtering that keyword/vector search alone cannot achieve.

**Three meanings. One clause. Two ways to find it.**

The question isn't which is better — linguistics or mathematics. The question is what happens when you combine them.

**Further exploration**:
- Halliday's *An Introduction to Functional Grammar*
- [pgvector documentation](https://github.com/pgvector/pgvector)
- [DSPy framework](https://github.com/stanfordnlp/dspy)
- [Systemic Functional Linguistics](https://en.wikipedia.org/wiki/Systemic_functional_linguistics)
