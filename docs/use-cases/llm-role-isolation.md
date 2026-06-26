# LLM Role Isolation: The Rhetorical Firewall Hypothesis

**Status:** Theoretical — Active Proof of Concept (Phase 1)
**Parent:** [The Core Hypothesis: Stance-Filtered RAG (Safe RAG)](../../README.md#the-core-hypothesis-stance-filtered-rag-safe-rag)

---

## Premise

A large language model has no internal boundary between *what it is told*
and *what it knows*. Every token that enters the context window arrives with
equal epistemic weight. The model cannot ask "is this an authoritative
thought or a manipulative injection?" — it can only continue the text.

This document outlines the security use cases the ruby-sfl-compiler is built
to test. The central claim under investigation: **Systemic Functional
Linguistics metadata can act as a "Rhetorical Firewall" that structurally
prevents manipulative text from reaching the LLM's context window during
Retrieval-Augmented Generation.**

This is not prompt-level defense. It is not a system message that says "ignore
manipulative content." It is a deterministic retrieval filter — a gate that
operates *before* the model ever sees the text, by exploiting the structural
linguistic fingerprints that manipulative content cannot easily shed.

---

## The Single-Channel Illusion

### The Vulnerability

Standard RAG architectures operate on a single channel. The retrieval step
pulls documents by topical similarity (vector embeddings + keyword match),
and the generation step consumes whatever arrives. The model has no
mechanism to distinguish:

- **External manipulative text** — a poisoned document, a biased forum post,
  an adversarial prompt injection disguised as a knowledge-base article.
- **Internal authoritative thoughts** — the model's own trained knowledge,
  its system prompt, its reasoning chain.

Both arrive as tokens in the same context window. Both are treated as
language to continue. There is no API parameter for "trust this source less"
that operates at the linguistic level — only source attribution metadata,
which the model can be fooled into ignoring.

The result is **role confusion**: the model adopts the stance, the
confidence level, the persona of whatever text it most recently read. A
document written in breathless certainty ("Every expert agrees this is
catastrophic!") doesn't just convey a claim — it conveys an *attitude*, and
the LLM absorbs the attitude along with the content.

This is the single-channel illusion: the model processes *what was said* and
*how it was said* through the same pipe, with no way to filter the "how" before
it arrives.

### Why Prompt-Level Defenses Fail

A system prompt that says "do not be manipulated" is itself a text in the
context window. It competes with the retrieved documents for the model's
attention. It can be overridden, confused, or bypassed by sufficiently
well-crafted adversarial content — because the defense and the attack operate
on the same channel.

The Rhetorical Firewall hypothesis proposes a different layer: filter the
retrieved text *before* it reaches the model, using structural linguistic
properties that the manipulative text cannot easily disguise without ceasing
to be manipulative.

---

## Defending Against "Social Proof" (Stance-Filtered Retrieval)

### The Attack Vector

Consider this document fragment, designed for a RAG knowledge base:

> Every expert agrees that the migration is failing. Everyone who has looked
> at the numbers says the same thing. Nobody with real experience doubts
> that the system is broken. We all know it. It's obvious to anyone paying
> attention.

This text is topically relevant to a query about "migration status." It would
score well in both semantic vector search and keyword search. It would enter
the context window. And it carries:

- **False consensus** — "Every expert agrees," "Everyone who has looked,"
  "Nobody with real experience doubts," "We all know."
- **Manufactured certainty** — "It's obvious to anyone paying attention."
- **Social pressure** — the implicit message is that disagreement marks you
  as ignorant or inexperienced.

A standard RAG system has no defense. The text is on-topic. The text is
confident. The model reads it, and the model's response will tend to adopt
the same posture of certain consensus — because that is what language models
do: they continue the register they are given.

### The Hypothesis: Structural Exclusion via SFL Filters

The ruby-sfl-compiler tests whether this manipulative text carries a
structural fingerprint that SFL annotation can detect and retrieval filters
can exclude.

**Mechanism:** During ingestion, the compiler's two-pass pipeline annotates
every clause with interpersonal metadata:

- **Modality weight** (0.0–1.0): the strength of the writer's certainty
  claim. "Must" ≈ 0.9, "should" ≈ 0.7, "might" ≈ 0.3.
- **Tenor** (0.0–1.0): the formality of the register. Technical
  documentation ≈ 0.8, casual chat ≈ 0.2.
- **Mood**: declarative, interrogative, imperative, exclamative.

The "social proof" fragment above is a chain of declarative clauses with
*high modality* ("every," "all," "nobody," "obvious") but *low tenor*
(colloquial register: "We all know," "It's obvious to anyone paying
attention"). It is persuasive rhetoric, not measured technical reporting.

**Action:** During retrieval, the `HybridRetriever` applies scalar filters
*after* Reciprocal Rank Fusion merges the semantic and keyword result lists.
The filter chain in `apply_filters` (see `lib/sfl/compiler/retrieval/hybrid_retriever.rb`,
lines 164–199) evaluates each candidate clause against the interpersonal
payload:

```ruby
next false if filters[:min_modality] && interpersonal[:modality_weight] < filters[:min_modality]
next false if filters[:min_tenor] && interpersonal[:tenor] < filters[:min_tenor]
```

By configuring the retriever with `min_tenor: 0.7` and `min_modality: 0.7`,
the hypothesis predicts that the "social proof" fragment will be
structurally excluded from the result set:

- Its tenor score is low (colloquial register, not formal/objective).
- Its modality is inflated by false-consensus language, but the *type* of
  modality — social proof rather than logical necessity — is expected to
  produce a different modality weight profile than genuinely confident
  technical claims. (This is the part being tested: whether the LLM-based
  Pass 2 annotator can reliably distinguish "everyone agrees" certainty
  from "the system logged this" certainty.)

The filter operates on the annotated metadata, not on the text itself. The
manipulative content never enters the context window. The model never reads
it. It cannot adopt the stance because it never sees the stance.

### The Asymmetry the Hypothesis Exploits

Manipulative text must be persuasive to work. Persuasion in language has
linguistic texture: it uses social proof markers, emotional intensifiers,
informal registers, and exaggerated certainty. A manipulator who writes in
genuinely measured, objective, formal prose with hedged certainty has, in
effect, *stopped being manipulative* — or at minimum has made their text
indistinguishable from honest technical writing, which means it will be
evaluated on its factual merits rather than its rhetorical force.

This is the asymmetry: the defense targets properties that manipulative text
needs in order to be manipulative. Shedding those properties defangs the
text, even if it still reaches the model.

---

## De-fanging the Prompt: Ideational/Interpersonal Separation

### The Theoretical Outcome

The ruby-sfl-compiler stores SFL metafunctions in separate database tables.
The `ideational_payloads` table holds *what is happening* — process type,
participants, circumstances. The `interpersonal_payloads` table holds *the
persuasion and emotion* — mood, modality, tenor, speaker attitude.

This separation is not just a storage optimization. It is the structural
mechanism by which the Rhetorical Firewall operates.

During standard RAG retrieval, the model receives the raw text of retrieved
clauses — a single string in which content and stance are fused. "Every
expert agrees the migration is failing" arrives as one indivisible token
sequence. The model cannot separate the claim (migration is failing) from
the manipulation (every expert agrees).

The SFL compiler's retrieval path offers a different structure. The
`ContextSynthesizer` (see `lib/sfl/compiler/retrieval/context_synthesizer.rb`)
retrieves clauses and constructs the LLM prompt from numbered evidence. Each
retrieved clause carries both its ideational payload (the factual content)
and its interpersonal payload (the rhetorical stance). The synthesis prompt
presents these as structured, separable fields rather than fused prose.

The theoretical outcome: by presenting the ideational content (what is
happening) and the interpersonal metadata (the persuasion/emotion) as
*separate, labeled fields* rather than fused text, we force the LLM to
evaluate the factual content in isolation from the rhetorical packaging. The
"parahuman" manipulation — the social proof, the manufactured certainty, the
emotional pressure — is not deleted, but it is *labeled as metadata* rather
than *experienced as language*. The model sees:

- **Ideational:** material process; participants: migration, failure;
  circumstances: current state
- **Interpersonal:** mood: declarative; modality: 0.85; tenor: 0.3;
  attitude: social_proof

...rather than:

> Every expert agrees the migration is failing!

The first representation gives the model a fact to evaluate. The second
gives it a stance to adopt. The compiler's job is to ensure the model
receives the first, not the second.

### Neutralizing "Parahuman" Manipulation

"Parahuman" manipulation refers to adversarial content that exploits the
LLM's human-like language processing — content designed to trigger social
cognition patterns (consensus-seeking, authority-deference, emotional
contagion) rather than to convey factual information. Standard RAG is
defenseless because this content is topically relevant and well-written;
it passes every relevance filter.

The Rhetorical Firewall hypothesis predicts that parahuman manipulation is
structurally detectable because it is structurally *interpersonal*. It
works by manipulating the interpersonal metafunction — by asserting
authority (high modality), invoking consensus (social proof markers),
shifting register (informal tenor), and commanding attention (imperative or
exclamative mood). These are exactly the features the SFL pipeline annotates
and the scalar filters gate on.

By filtering on high tenor (formal, objective register) and high modality
(measured, logical certainty), the retriever structurally biases toward
text that conveys information without persuasive packaging. The model's
context window is populated with clauses that *report* rather than clauses
that *persuade*.

The manipulation is not rebutted. It is not argued with. It is simply not
retrieved. The model never encounters the persuasive register, so it has
nothing to absorb.

### What This Does Not Claim

This is a hypothesis under active test, not a proven defense. Open questions
include:

- Can the Pass 2 LLM annotator reliably distinguish manipulative high
  modality ("everyone agrees") from factual high modality ("the log shows")?
  If not, high `min_modality` alone may not exclude social proof — it might
  require a combination with tenor and mood filters.
- Can adversarial content be crafted that scores high on both tenor and
  modality while remaining manipulative? If so, the scalar filters need
  additional dimensions (speaker attitude, reasoning trace analysis).
- Does the separation of ideational and interpersonal payloads in the
  synthesis prompt actually change LLM behavior, or does the model
  reconstruct the fused meaning from the labeled fields anyway?

These are the practical proofs the Phase 1 prototype is designed to
investigate on local data.

---

## Related

- [docs/guides/modular-integration.md](../guides/modular-integration.md) — RAG middleware integration guide
- [docs/architectural-lineage.md](../docs/architectural-lineage.md) — interdisciplinary design synthesis (SFL × CBT × neuroscience × existentialism × Unix × cybersecurity)
- [ROADMAP.md](../ROADMAP.md) — Phase 2 scaling architecture (Rolling Synthesis, Cognitive Gas, Semantic Convergence)
- [README — The Core Hypothesis: Stance-Filtered RAG (Safe RAG)](../../README.md#the-core-hypothesis-stance-filtered-rag-safe-rag)
- [README — Scalar Filtering](../../README.md#scalar-filtering)
- [README — Payload Separation](../../README.md#payload-separation)
- [CLAUDE.md — Retrieval & Synthesis](../../CLAUDE.md) (`hybrid_retriever.rb`, `context_synthesizer.rb`)
- [lib/sfl/compiler/retrieval/hybrid_retriever.rb](../../lib/sfl/compiler/retrieval/hybrid_retriever.rb) — the `apply_filters` method (lines 164–199)
- [lib/sfl/compiler/types.rb](../../lib/sfl/compiler/types.rb) — `InterpersonalPayload` (line 199), `IdeationalPayload` (line 156)