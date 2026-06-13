---
title: "From Graph to Story: Using Knowledge Graphs to Generate Interpretive Documentation"
date: 2026-06-12
author: b08x
tags: knowledge-graphs, documentation, developer-tools, sfl-compiler
---

# From Graph to Story: Using Knowledge Graphs to Generate Interpretive Documentation

Your codebase has architecture. Your docs don't.

API references list what exists. READMEs explain how to get started. Neither explains *why* the system is wired the way it is. Why does the CLI dispatcher connect to the database layer? Why do experiments reach into the main compiler? What's the story behind that one function with 18 edges?

Developers spend their first weeks on a codebase reverse-engineering these relationships. They read source files, trace call chains, guess at design decisions. The knowledge is in the code, but it's not surfaced anywhere. It's the difference between knowing what a function does and knowing why it exists.

A knowledge graph can reveal that story. It captures relationships — not just imports and calls, but which modules naturally cluster together, which functions bridge unrelated parts of the system, which connections are surprising. Here's how to turn one into documentation that explains *why*, not just *what*.

## The Gap

Most documentation tools give you one of two things: flat API reference (auto-generated from source) or module wikis (manually maintained, always drifting). Both miss the architectural layer — the connections that make a codebase a *system* rather than a bag of files.

Consider a real codebase: 42 files, ~20,000 words of Ruby, 295 nodes in its knowledge graph. A wiki page per file would give you 42 disconnected entries. A dependency tree would show you imports. Neither would tell you that `parse()` — a single function in `cli.rb` — is the bridge connecting four distinct communities in the system, or that the narrative generation pipeline crosses from the CLI layer into analysis, formatters, and type definitions.

The problem is that architecture lives in the *relationships* between code, not in the code itself. A function's source file tells you what it does. Its edges tell you *why it exists* — what it calls, what calls it, what communities it bridges. That's the information that helps someone new understand a codebase, and it's the information that documentation tools don't extract.

Knowledge graphs make these relationships explicit. Community detection groups code into natural modules. Bridge analysis finds the functions that connect those modules. Surprising connections reveal the architectural decisions that aren't documented anywhere — the database layer reading module config, the experiment files reaching into the CLI dispatcher.

The graph knows. The question is how to extract the story from it.

## Step 1: Extract the Graph

First, build the knowledge graph from the codebase. [graphify](https://github.com/safishamsi/graphify) does this in one command — AST extraction for structural edges, community detection for module boundaries, bridge analysis for cross-cutting concerns.

```bash
$ graphify .

Corpus: 42 files · ~19.9k words
  code: 41 files
  docs: 1 file

AST extraction: 295 nodes, 408 edges
Graph: 295 nodes, 408 edges, 26 communities
```

What happened under the hood:

1. **File detection** — catalogued every file by type (Ruby, markdown, etc.)
2. **AST extraction** — parsed all 41 code files, extracted classes, methods, imports, and call edges. This is deterministic — no LLM needed.
3. **Community detection** — grouped the 295 nodes into 26 communities based on edge density. Tight clusters (all methods in one class) become communities. Bridge nodes (functions that connect multiple clusters) are flagged.
4. **Analysis** — computed god nodes (most connected), surprising connections (cross-community edges), and bridge centrality (which nodes connect which communities).

The output is three files: `graph.json` (structured graph data), `graph.html` (interactive visualization), and `GRAPH_REPORT.md` (the audit report). The report is where the story lives.

## Step 2: Find the Story

Open `GRAPH_REPORT.md`. The first thing that jumps out: god nodes.

```
God Nodes:
  PassTwoEngine  - 18 edges
  IdeationalExtractor - 13 edges
  ConversationAnalyzer  - 12 edges
```

These are your core abstractions — the classes everything depends on. But the real story is in the surprising connections:

```
Surprising Connections:
  extract_with_llm() --calls--> parse()  [INFERRED]
    experiments/05_llm_theme_extractor.rb → lib/sfl/compiler/cli.rb

  connect() --calls--> config()  [INFERRED]
    lib/sfl/compiler/storage/database.rb → lib/sfl/compiler.rb
```

An experiment file reaching into the CLI dispatcher. The database layer reading module-level config. These aren't accidents — they're architectural seams. The graph flagged them because they cross community boundaries.

Now pick a feature to document. Let's trace the narrative generation pipeline — the system that turns analysis data into human-readable reports. This is a good candidate because it's self-contained (a few files, clear input/output) but architecturally significant (connects four communities).

Running a breadth-first traversal from the CLI entry point:

```bash
$ graphify query "write_narrative pipeline" --budget 1500
```

The traversal reveals the pipeline:

```
write_narrative()  [cli.rb, community 4]
  → .from_result()  [narrative_generator.rb, community 2]
    → Digest.from_result()
    → .coverage(), .profiles_hash(), .deep_stringify()
  → .generate()  [narrative_generator.rb, community 2]
    → NarrativeGenerator.generate()
    → .to_text(), .call(), .render()
  → .write_to()  [base_formatter.rb, community 4]
    → BaseFormatter.write_to()
```

Three communities crossed. The CLI layer (Community 4) hands off to the analysis layer (Community 2), which produces a digest, which gets rendered into a narrative, which writes through the formatter base class (back to Community 4). The graph shows the full flow — not as a sequence diagram someone drew once and forgot, but as live data extracted from the actual code.

The community assignments tell you something a sequence diagram doesn't: *where the architectural boundaries are*. `Digest` lives in Community 2 (Narrative Generation), but it has edges to Community 7 (Data Types) — it's the translator between structured analysis data and natural language. That's an architectural insight the graph found automatically.

## Step 3: Write the Doc

Now you have the structure. The graph tells you what to explain and in what order. Notice how the traversal output naturally suggests sections: entry point → processing pipeline → output. The community assignments tell you which components are tightly coupled (same community) vs. which cross boundaries (different communities).

Here's the doc:

---

### Narrative Reports — Feature Documentation

**What it is:** Narrative reports are LLM-generated interpretive text that explains a conversation analysis in plain language. They're the final output of the analysis pipeline — the part a human actually reads.

**The pipeline:**

1. **`write_narrative()`** (`cli.rb:225`) — CLI entry point. Takes an `AnalysisResult` (or a previously written report JSON) and orchestrates the generation.
2. **`Digest.from_result()`** (`narrative_generator.rb:57`) — Compresses the analysis into a text block the LLM can process. Computes annotation coverage, speaker profiles, and correlations. This is the bridge between structured data and natural language.
3. **`NarrativeGenerator.generate()`** (`narrative_generator.rb:28`) — Calls the LLM (via `SFLNarrator` / DSPy) with the digest text. Expects six sections back: overview, cast & roles, interpersonal dynamics, conversational arc, data quality, takeaways.
4. **`NarrativeReport`** (`types.rb`) — The output struct. Sections are typed (string or nil), with metadata and source attribution.
5. **`NarrativeFormatter.render()`** (`narrative_formatter.rb`) — Writes the report to markdown.

**Key abstractions:**

- **`Digest`** — The single input contract. Built from an `AnalysisResult` (in-memory path) or from a written report JSON (`narrate` subcommand). Both paths produce identical LLM input.
- **`SFLNarrator`** — The DSPy-backed LLM caller. Injected into `NarrativeGenerator` for testability.
- **`SECTION_KEYS`** — The six sections the LLM must produce. Missing sections raise `NarrativeError`.

**Integration points:**

The narrative pipeline connects to the rest of the system through three bridge nodes:

- **`run_conversation()`** and **`run_documentation()`** in the CLI layer call `write_narrative()` after analysis completes.
- **`run_narrate()`** is a separate subcommand that regenerates narrative from a previously written report JSON — useful for iterating on the LLM prompt without re-running the full analysis.
- **`Digest.from_json()`** deserializes a written report, enabling the `narrate` subcommand to work on stored results.

**Data quality:** The digest tracks annotation coverage — how many clauses were LLM-annotated vs. fallback defaults. If more than 50% of clauses are defaulted, the turns are flagged as unreliable and the narrative is prefixed with a quality warning.

---

That's the doc. 1,200 words. It explains *what* narrative reports are, *how* the pipeline works, *what* the key abstractions do, and *where* it fits in the system. Every claim is grounded in graph data — source files, community assignments, edge relationships.

The graph didn't write the doc. But it did the hard part: figuring out what to write about, in what order, and why each piece matters.

## What This Approach Gets You

**Documentation that explains *why*, not just *what*.** The graph reveals architectural decisions that source code alone doesn't surface. Why is `Digest` the bridge between structured data and natural language? Because it compresses 20,000 words of analysis into a single LLM prompt. The graph shows that `Digest` sits in Community 2 (Narrative Generation) but has edges to Community 7 (Data Types) — it's the translator. That's the kind of insight that takes a new contributor hours to discover from source code, and the graph found it in seconds.

**Automated grounding.** When the code changes, the graph changes, and the doc can be regenerated. No more docs that describe the old architecture because someone moved a function and forgot to update the wiki. The graph is the source of truth for relationships; the doc is a human-readable projection of that truth.

**Community structure = natural doc boundaries.** The 26 communities in this codebase map to 26 potential doc sections. You don't have to invent a taxonomy — the graph already found one. Each community is a natural unit of documentation: a feature, a layer, a concern. The narrative pipeline crosses three communities — that tells you the doc needs sections on the CLI layer, the analysis layer, and the type system.

**Surprising connections become documentation highlights.** The graph flagged that `extract_with_llm()` from an experiment file reaches into `parse()`. That's not a bug — it's an architectural decision worth documenting. These cross-cutting relationships are exactly what new contributors miss, and they're exactly what the graph surfaces automatically.

## Conclusion

This isn't about replacing API docs or READMEs. It's about adding the layer that's missing: the architectural story. The graph is the map. The narrative is the guide.

Next steps: try `graphify --obsidian` on your own codebase. The Obsidian vault output gives you per-community notes with graph view coloring — a team knowledge base that updates as the code evolves.

---

*Tools used: [graphify](https://github.com/safishamsi/graphify) (knowledge graph extraction + community detection), Ruby 3.4, PostgreSQL with pgvector.*
