# Gödel, Escher, SFL: A Lens on the Compiler

*A companion to `poignant-guide-to-sfl-compiler.md`, using a deliberately
different lens. why's guide asked how this gem feels; Hofstadter's asks what
it **is** — a stack of formal systems, each deriving meaning from the one
below, with one genuine strange loop at the top.*

Everything described is the actual v0.1.0 behavior. Chapter citations refer
to *Gödel, Escher, Bach*.

---

## 1. Meaning From Form: Pass 1 Is a pq-System

Hofstadter's pq-system manipulates meaningless strings (`--p---q-----`) by
typographical rule, and the strings only *become* statements about addition
when an observer notices the isomorphism: hyphens map to numbers, `p` to
"plus." Meaning is not injected; it is discovered as shared structure
(source: ch02).

Pass 1 of this compiler is a pq-system that earns its keep. The
`IdeationalExtractor` knows nothing about doing or thinking. It applies
typographical rules to spaCy's symbols:

```
nsubj  → Actor          # rule, not understanding
dobj   → Goal
lemma ∈ mental_verbs → process_type: "mental"
```

The dependency label `nsubj` means nothing in itself. The hardcoded verb
lists are derivation rules, not knowledge. And yet `process_type: "mental"`
comes out *correct* — because the rules were chosen to be isomorphic to a
real structure in English grammar. When the experiments directory reports
that rule-based Theme/Rheme extraction scored 16.7% while transitivity
classification works, it is reporting exactly where the isomorphism holds
and where the typographical system's form stops mapping onto linguistic
reality. Meaning lives in the mapping, and the mapping has edges.

## 2. Levels of Description: The Ant Fugue in the Report

Is a fugue one piece of music or four independent voices? Hofstadter's
answer — both, depending on which level you describe it at — and his ant
colony Aunt Hillary, who is intelligent at a level where no single ant is
(source: ch10).

This codebase is a tower of such levels, and each one has its own
vocabulary, deliberately:

```
token → clause → turn/section → speaker profile → conversation insight
```

A single clause has no "tenor variance." A speaker does. No clause
"contributed 6 of 19 turns." The `AnalysisResult` holds all levels at once,
and the three formatters are three different *level choices* over the same
object: CSV speaks at turn level, the speaker-profiles table at colony
level, the JSON keeps every level for whoever asks.

The infamous all-0.5 report (see `KNOWN_ISSUES`/session history) was
precisely a **level-confusion bug**: clause-level placeholder values
(meaningless individually, each one just "I don't know") were aggregated
upward, and at the speaker level the aggregate *looked like* a colony-level
fact — "this speaker is mixed-formality" — when no signal existed at the
ant level at all. Aunt Hillary made of dead ants, still apparently
conversing. The fix (`annotation_source`, the Data Quality banner) works by
carrying level-zero provenance up the tower so higher levels can refuse to
pretend.

## 3. Truth versus Provability: The map_with_index Incident

Gödel's distinction: in a sound formal system, everything provable is true,
but not everything true is provable — and a system whose derivation rules
quietly diverge from the domain can prove things that are simply false
(source: ch08, ch14).

This repository ran the experiment. For its entire life,
`HybridRetriever`'s unit specs were green: within the formal system of the
test suite, "retrieval works" was a theorem. Meanwhile, against a real
database, retrieval had never returned a row — `map_with_index` does not
exist on Sequel datasets, and a `rescue` converted the `NoMethodError` into
an empty result, forever.

What failed was the **isomorphism between the formal system and its
intended interpretation**. The test doubles answered `map_with_index`
politely; real datasets do not. The moment the doubles' behavior diverged
from the domain objects they modeled, theoremhood ("specs pass") detached
from truth ("rows come back"). The suite remained perfectly consistent —
and perfectly capable of proving a falsehood about the world, because its
axioms (the stubs) no longer mapped onto reality.

The repair was not more theorems. It was *jumping out of the system*
(source: ch15): a live run against PostgreSQL, outside the suite's axioms
entirely. No amount of derivation inside the test system could have
revealed the divergence, for the same reason TNT cannot see its own Gödel
sentence: the flaw was in the system's relationship to its interpretation,
which is invisible from inside. The codebase now encodes the lesson
twice — honest doubles that answer only what Sequel answers, and a standing
practice that CLI `run_*` paths are verified by live execution rather than
in-system proof.

## 4. The Location of Meaning: annotation_source as Decoder Key

A phonograph record, an undeciphered inscription, a strand of DNA: is the
meaning *in* the object, or in the decoder? Hofstadter's answer is that a
message needs three layers — frame ("this is a message"), outer message
("decode me this way"), inner message (the content) — and shipping the
inner message without the outer one invites confident misreading
(source: ch06).

`tenor: 0.5` is an inner message with two wildly different readings:

- "the LLM judged this clause mixed-formality" — a measurement
- "Pass 2 failed and a placeholder was inserted" — an absence

The bits are identical. Before this session, the database stored only the
inner message, and every decoder downstream chose the flattering reading.
The fix was to ship the outer message alongside:

```ruby
attribute :annotation_source, Types::AnnotationSource  # llm | fallback | stub
```

`annotation_source` is the decoder key — it tells every future reader
*which isomorphism to apply* to the number sitting next to it. The JSON
report's `annotation_coverage` and the markdown Data Quality banner are
that key propagated to human-readable levels. Same bits, located meaning.

## 5. The Strange Loop: The Gem Reads Its Own README

Here the hierarchy genuinely tangles. During live verification, this
sequence ran:

```bash
sfl-analyze documentation README.md --store
sfl-analyze context "what is this project about?"
```

Step one: the compiler parsed *its own description* — clauses about Pass 1
flowed through Pass 1; sentences about tenor were assigned tenors; the
paragraph explaining scalar filtering was stored behind scalar indices it
describes. Step two: the system retrieved those clauses and had an LLM
synthesize an answer about what the system is, citing the system's own
sentences as evidence — through the very retrieval mechanics the cited
sentences document.

That is a tangled hierarchy in Hofstadter's precise sense: the object level
(text being processed) and the meta level (text describing the processor)
collapse into one loop, and the system functions as both subject and
instrument without contradiction (source: ch20, ch16). It even produces the
charming Gödelian corollary: ask it about itself with stance filters set to
`--min-tenor 0.99` and it truthfully reports it has nothing sufficiently
formal to say about itself.

Two design choices keep the loop strange rather than vicious:

1. **Citations are bounds-checked.** `ContextSynthesizer` never trusts the
   LLM's self-reference; evidence numbers are verified against the actual
   list before becoming claims (`enriched[number - 1]`, positives only).
   Self-reference, yes — *unaudited* self-reference, no.
2. **The system reports its own incompleteness.** The Data Quality section
   is the report describing the reliability of the process that produced
   the report — self-representation used to bound confidence, not inflate
   it. A formal system that cannot prove everything, saying so, in its own
   output format.

## 6. BlooP, FlooP, and the Power/Self-Knowledge Trade

No language powerful enough to express all computable functions can also
decide halting for itself; you buy power by giving up self-transparency
(source: ch13, ch17).

The two passes sit on opposite sides of that trade, deliberately:

- **Pass 1 is BlooP-like**: rule lists, bounded loops, no LLM. It is weak —
  it cannot judge formality, it failed at Theme/Rheme — but it is fully
  inspectable and *never wrong about what it did*. Its output is always
  preserved (`PassOneError` aside, there is no "Pass 1 fallback" because
  Pass 1 cannot half-fail).
- **Pass 2 is FlooP-like**: an LLM can judge anything, including things no
  rule list could express — and precisely because of that power, it cannot
  certify its own outputs. The engine treats it accordingly: typed output
  contracts (the velvet rope, in the other document's dialect), index
  verification, retry-once, provenance marking. Power, wrapped in
  externally-imposed checks it could not provide for itself.

The architecture is the trade-off made structural: keep the weak,
self-transparent system as the substrate that always survives, and let the
powerful, opaque system annotate on top, never beneath.

---

## Coda: A Brief Dialogue

*Achilles and the Tortoise inspect a freshly generated report.*

**Achilles**: Every speaker scores 0.5! What remarkable uniformity of
character these six people have.

**Tortoise**: Or remarkable uniformity of *absence*, Achilles. Tell me —
does the report say anywhere how it knows what it knows?

**Achilles**: There's a banner here... "100% of clauses carry fallback
values — placeholders, not findings." Oh. So the report is describing its
own ignorance?

**Tortoise**: Better — it is a description of speakers that contains a
true description of itself as a failed description of speakers. Gödel
would ask for royalties.

**Achilles**: Then which level should I believe, the table or the banner?

**Tortoise**: Both, dear Achilles. The table is a perfectly valid theorem
of the system that produced it. The banner tells you the system's axioms
were, on this occasion, about nothing at all.

---

*Companion piece: `poignant-guide-to-sfl-compiler.md` (same codebase,
why-the-lucky-stiff lens — kept separate on purpose; the lenses do not
mix). For the machinery itself: `README.md`, `CLAUDE.md`.*
