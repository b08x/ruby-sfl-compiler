# A (Poignant) Guide to the SFL Compiler

*In which we discover that this gem is a machine for doing to sentences what
why the lucky stiff did to Ruby: asking not just what they say, but how they
carry themselves while saying it.*

> Style note: this document applies the Poignant article-scaffolding pattern —
> each section maps one of why's mental models onto a real mechanism in this
> codebase. The metaphors are structural, not decorative. Everything described
> here is how the code actually works as of v0.1.0.

---

## 1. Parts of Speech, or: Every Clause Wears Clothes

Ruby, why taught us, is coderspeak — nouns are variables, verbs are methods,
and a sentence is a short collection of words and punctuation encompassing a
single thought.

This gem takes that mapping and runs it in reverse. You hand it human
sentences, and it files paperwork on their grammar:

```ruby
pairs = pipeline.compile_pass_one("The system processes user input.")
clause, ideational = pairs.first
ideational.process_type   # => "material" — a doing-word kind of sentence
```

Pass 1 is the grammarian: spaCy diagrams the sentence, the
`IdeationalExtractor` decides — with hardcoded verb lists, no magic — whether
the clause is *doing* (material), *thinking* (mental), *saying* (verbal), or
just *being* (relational).

But here is the poignant part. Pass 2 doesn't ask what the sentence says.
It asks how the sentence is **dressed**:

- **tenor** (0.0–1.0): is it wearing a tuxedo or pajamas?
- **modality** (0.0–1.0): does it stride in shouting "must!" or shuffle in
  whispering "perhaps"?
- **mood**: is it telling, asking, commanding, or exclaiming?

Most retrieval systems strip the clothes off and index naked topic-meat.
This one keeps the wardrobe in a separate table (`interpersonal_payloads`)
with its own indices, so you can later ask for "only the confident, formal
sentences about deployment" and actually get them.

## 2. The Velvet Rope, or: Dry::Struct at the Door

The triple-equals, why said, is a longer, sagging rope. It doesn't ask "are
you exactly this?" — it asks "do you *belong* here?"

`lib/sfl/compiler/types.rb` is a nightclub with rope everywhere:

```ruby
ModalityWeight = Types::Float.constrained(gteq: 0.0, lteq: 1.0)
MoodType = String.enum("declarative", "interrogative", "imperative", "exclamative")
AnnotationSource = String.default("llm").enum("llm", "fallback", "stub")
```

When the LLM returns `modality_weight: 9.9` for a clause — and one day it
will, because LLMs are enthusiastic — the rope holds. `Dry::Struct::Error`
bounces the value at the door, and the engine quietly substitutes defaults
for that one clause rather than letting a nonsense number into your database.

The door policy is written down in `PassTwoEngine#payload_from`: try to seat
the guest, and if they don't belong, log a `[WARN]` and seat a placeholder
instead. Nobody gets in wearing a 9.9.

(A craftsman's footnote: the rope must be tied in the right order.
`.enum(...).default(...)` raises at class-definition time in dry-types;
the default goes on *before* the enum closes the set. The codebase learned
this the honest way.)

## 3. The Mad Cop, or: annotate_batch Goes Through the Alphabet Once

"Mad" Dick Robinson talked the jumper down by going through the alphabet —
one letter at a time, each step a distinct moment of processing, no letter
visited twice in a panic.

Pass 2 used to be a panicked cop: one LLM call per clause, 1,260 clauses,
two hours of radio chatter. Now it is a disciplined one
(`PassTwoEngine#annotate_batch`):

```ruby
chunks = indexed.each_slice(batch_size).to_a       # ~12 clauses per call
annotated = parallel_map(chunks, concurrency) do |chunk|
  annotate_chunk(chunk, correlation_id)            # one moment of processing
end.flatten
```

The discipline has three rules, and they are why the thing is trustworthy:

1. **One retry, not a tantrum.** A chunk that fails transiently gets exactly
   one more chance. Then its clauses fall back to defaults. No layer above
   adds its own retries — one iterator, one budget.
2. **Never trust the suspect's numbering.** The LLM returns annotations
   tagged with an `index`. The engine looks each one up
   (`by_index[entry[:index]]`) instead of trusting array order, because
   models drop and shuffle list items the way drunks drop alphabet letters.
3. **Pre-sized slots, no shoving.** `parallel_map` writes each chunk's result
   into `results[i]` — distinct slots, order preserved by construction, no
   mutex theatrics.

## 4. The Video Cassette, or: Analyzers Need a VCR

A module, why said, is a video cassette — a storage facility for methods.
But a cassette is useless without a player, and a proper mixin documents
what the player must provide.

The analyzers in this gem are cassettes:

```ruby
SFL::Compiler::Analysis::ConversationAnalyzer.new(
  pipeline: pipeline,                 # the player must provide a deck
  on_progress: ->(e) { ... }          # and a little window to watch through
)
```

They contain no `puts`, no `exit`, no `ENV`. They cannot play themselves.
The CLI (`lib/sfl/compiler/cli.rb`) is today's VCR: it parses your buttons,
calls `Bootstrap` to plug everything into the wall, slots the cassette in,
and prints what comes out of the progress window. When a TUI arrives, it is
just a different player for the same cassettes — the contract is the
constructor signature, nothing more.

`Bootstrap` itself is the wall socket, and it is the **only** thing in the
gem allowed to touch `ENV`. Hand it a provider it doesn't recognize and it
refuses loudly — `Unsupported DSPY_PROVIDER: mystery/model` — instead of
quietly grabbing somebody else's API key, which is what the old template
script used to do.

## 5. Ghost Methods, or: The 0.5 That Haunted the Report

`method_missing` is Ruby's ghost door: calls to methods that don't exist
can be caught and answered by *something else*, and if that something
answers too agreeably, you never learn the method was missing at all.

This codebase was haunted twice, and both hauntings are instructive.

**The first ghost** lived in `HybridRetriever`. Both search paths ended in
`.map_with_index { ... }` — a method that does not exist on Sequel datasets.
The `NoMethodError` rose every single time, and a friendly
`rescue StandardError` caught it, logged a whisper to journald, and returned
`[]`. The retriever's unit tests passed, because their test doubles politely
answered `map_with_index` like a ghost saying "yes, dear." Against a real
database, retrieval had returned zero rows for its entire existence. The
exorcism was boring, as exorcisms should be: make the test doubles only
answer what real datasets answer, watch the test finally fail, change the
call to `.to_a.each_with_index.map`.

**The second ghost** was subtler. When Pass 2 failed, clauses got default
values — tenor 0.5, modality 0.5 — which flowed into averages and came out
the other end as a report solemnly declaring every speaker "0.5 (mixed)".
The ghost answered every question with the midpoint of the scale, and the
midpoint looks exactly like a finding. The fix was to make the ghost wear a
bell:

```ruby
attribute :annotation_source, Types::AnnotationSource  # llm | fallback | stub
```

Now every defaulted clause is tagged, the markdown report opens with a
**⚠️ Data Quality** section counting them, and a report that is 100%
placeholder says so in bold instead of impersonating analysis.

The moral, in why's spirit: ghosts are fine — *silent* ghosts are the bug.
Override `method_missing` to fail loudly, or at least to ring.

## 6. The Deer Language, or: Reading the Smoke from Your Own Chimney

Regular expressions, why said, are smoke signals blown from a deer's
nostrils — arduous to compose, but once the smoke is up, hooking your elbow
around it is easy.

The retrieval layer speaks two dialects of smoke:

```sql
to_tsvector('simple', text) @@ plainto_tsquery('simple', ?)
```

This is keyword smoke, and it has a deer-language quirk worth tattooing
somewhere: the `'simple'` configuration keeps stopwords, and `plainto_tsquery`
demands **every** word match. Ask the corpus *"what is this project about?"*
and you are demanding a single clause containing "what" and "is" and "this"
and "project" and "about" — the deer just stares at you. Ask for
*"scalar filtering"* and sixteen clauses raise their hooves.

The second dialect is vector smoke (pgvector cosine), which understands
paraphrase but only exists if you stored embeddings (`--store` with an
OpenAI key). The two are merged by Reciprocal Rank Fusion — two trackers
reading different smoke, voting on where the deer went.

And at the end, `ContextSynthesizer` hooks its elbow around the result: the
answer comes back with numbered citations, and the numbers are
bounds-checked before they're believed (`enriched[number - 1]` only for
positive, in-range numbers). Even when the smoke spells out an answer, you
verify which fires it actually came from.

---

## Closing: The Sentence About Sentences

The whole gem is one long sentence diagram of itself. It believes — and its
schema enforces — that *how* something was said is data: that "must" and
"might" deserve different rows, that a tuxedo clause and a pajama clause
should be filterable apart, and that when the machine doesn't know, it
should say "I don't know" in a tagged, countable, bannered way rather than
mumbling 0.5 and hoping.

why would have appreciated that last part most. Chunky bacon is best served
honestly labeled.

*Further reading: `README.md` for the front door, `USAGE.md` for the
operator's manual, `CLAUDE.md` for the map agents use, and
`lib/sfl/compiler/cli.rb` for the wiring all of this hides behind.*
