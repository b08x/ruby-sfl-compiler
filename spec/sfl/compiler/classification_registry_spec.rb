# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
require "spec_helper"

RSpec.describe SFL::Compiler::ClassificationRegistry do
  describe ".normalize" do
    context "with mood dimension" do
      it "returns exact matches for canonical moods" do
        expect(described_class.normalize(:mood, "declarative")).to eq(["declarative", :exact])
        expect(described_class.normalize(:mood, "interrogative")).to eq(["interrogative", :exact])
      end

      it "normalizes aliases to canonical values" do
        expect(described_class.normalize(:mood, "question")).to eq(["interrogative", :aliased])
        expect(described_class.normalize(:mood, "exclamatory")).to eq(["exclamative", :aliased])
      end

      it "maps unknown moods to default" do
        expect(described_class.normalize(:mood, "unknown_mood")).to eq(["declarative", :unknown])
      end

      it "normalizes Elliptical, nominal, and narrative moods correctly" do
        expect(described_class.normalize(:mood, "Elliptical")).to eq(["declarative", :aliased])
        expect(described_class.normalize(:mood, "nominal")).to eq(["fragment", :aliased])
        expect(described_class.normalize(:mood, "narrative")).to eq(["declarative", :aliased])
      end

      it "normalizes 'elliptical_fragment' to fragment, not declarative" do
        expect(described_class.normalize(:mood, "elliptical_fragment")).to eq(["fragment", :aliased])
      end

      it "normalizes 'continuative' to declarative" do
        expect(described_class.normalize(:mood, "continuative")).to eq(["declarative", :aliased])
      end

      it "normalizes rhetorical questions to interrogative, not declarative" do
        expect(described_class.normalize(:mood, "rhetorical_question")).to eq(["interrogative", :aliased])
        expect(described_class.normalize(:mood, "rhetorical question")).to eq(["interrogative", :aliased])
      end

      it "strips a trailing parenthetical qualifier before resolving the bare mood term" do
        expect(described_class.normalize(:mood, "declarative (elliptical)")).to eq(["declarative", :exact])
        expect(described_class.normalize(:mood, "interrogative (rhetorical)")).to eq(["interrogative", :exact])
      end
    end

    context "with theme_type dimension" do
      it "returns exact matches for canonical theme types" do
        expect(described_class.normalize(:theme_type, "unmarked")).to eq(["unmarked", :exact])
        expect(described_class.normalize(:theme_type, "marked")).to eq(["marked", :exact])
      end

      it "normalizes predicated and predicator theme types as canonical" do
        expect(described_class.normalize(:theme_type, "predicated")).to eq(["predicated", :exact])
        expect(described_class.normalize(:theme_type, "predicator")).to eq(["predicator", :exact])
      end

      it "normalizes process and modal theme types via aliases" do
        expect(described_class.normalize(:theme_type, "process")).to eq(["predicator", :aliased])
        expect(described_class.normalize(:theme_type, "modal")).to eq(["interpersonal", :aliased])
      end

      it "normalizes the adjectival 'interjectional' to the canonical 'interjection'" do
        expect(described_class.normalize(:theme_type, "interjectional")).to eq(["interjection", :aliased])
      end

      it "normalizes compound theme types containing multiple elements to multiple" do
        expect(described_class.normalize(:theme_type, "textual > interpersonal > topical")).to eq(["multiple", :exact])
        expect(described_class.normalize(:theme_type, "textual_interpersonal")).to eq(["multiple", :exact])
        expect(described_class.normalize(:theme_type, "textual,interpersonal")).to eq(["multiple", :exact])
        expect(described_class.normalize(:theme_type, "textual_unmarked")).to eq(["multiple", :exact])
      end

      it "normalizes compound theme types joined by the conjunction 'and' to multiple" do
        expect(described_class.normalize(:theme_type, "topical and interpersonal")).to eq(["multiple", :exact])
      end

      it "respects existing aliases like topical_unmarked" do
        expect(described_class.normalize(:theme_type, "topical_unmarked")).to eq(["topical", :aliased])
      end

      it "handles prefix/suffix stripping correctly" do
        expect(described_class.normalize(:theme_type, "textual_theme")).to eq(["textual", :exact])
        expect(described_class.normalize(:theme_type, "theme_unmarked")).to eq(["unmarked", :exact])
      end

      it "recognizes circumstantial as a canonical theme type" do
        expect(described_class.normalize(:theme_type, "circumstantial")).to eq(["circumstantial", :exact])
      end

      it "strips _theme suffix so circumstantial_theme resolves to circumstantial" do
        expect(described_class.normalize(:theme_type, "circumstantial_theme")).to eq(["circumstantial", :exact])
      end

      it "maps circumstantial sub-types to the circumstantial canonical" do
        expect(described_class.normalize(:theme_type, "temporal")).to eq(["circumstantial", :aliased])
        expect(described_class.normalize(:theme_type, "spatial")).to eq(["circumstantial", :aliased])
        expect(described_class.normalize(:theme_type, "causal")).to eq(["circumstantial", :aliased])
        expect(described_class.normalize(:theme_type, "conditional")).to eq(["circumstantial", :aliased])
        expect(described_class.normalize(:theme_type, "concessive")).to eq(["circumstantial", :aliased])
        expect(described_class.normalize(:theme_type, "manner")).to eq(["circumstantial", :aliased])
      end

      it "maps 'marking' to marked (model intended 'marked theme')" do
        expect(described_class.normalize(:theme_type, "marking")).to eq(["marked", :aliased])
      end

      it "maps no-value sentinels to unmarked" do
        expect(described_class.normalize(:theme_type, "null")).to eq(["unmarked", :aliased])
        expect(described_class.normalize(:theme_type, "none")).to eq(["unmarked", :aliased])
        expect(described_class.normalize(:theme_type, "n/a")).to eq(["unmarked", :aliased])
        expect(described_class.normalize(:theme_type, "")).to eq(["unmarked", :aliased])
      end
    end

    context "with mood dimension — extended aliases" do
      it "maps 'modal' to declarative (modality feature, not a mood category)" do
        expect(described_class.normalize(:mood, "modal")).to eq(["declarative", :aliased])
      end

      it "maps 'exhortative' to imperative (directive/hortatory clause)" do
        expect(described_class.normalize(:mood, "exhortative")).to eq(["imperative", :aliased])
      end

      it "maps 'conditional' and 'subjunctive' to declarative" do
        expect(described_class.normalize(:mood, "conditional")).to eq(["declarative", :aliased])
        expect(described_class.normalize(:mood, "subjunctive")).to eq(["declarative", :aliased])
      end

      it "maps 'subjective' (LLM near-miss for 'subjunctive') to declarative" do
        expect(described_class.normalize(:mood, "subjective")).to eq(["declarative", :aliased])
      end

      it "maps no-value sentinels to declarative" do
        expect(described_class.normalize(:mood, "null")).to eq(["declarative", :aliased])
        expect(described_class.normalize(:mood, "n/a")).to eq(["declarative", :aliased])
        expect(described_class.normalize(:mood, "")).to eq(["declarative", :aliased])
      end

      it "maps 'neutral' to declarative (LLM's 'no marked mood' = SFL's unmarked declarative)" do
        expect(described_class.normalize(:mood, "neutral")).to eq(["declarative", :aliased])
      end

      it "maps 'interjectional' and 'interjection' to minor (SFL treats interjections as minor clauses)" do
        expect(described_class.normalize(:mood, "interjectional")).to eq(["minor", :aliased])
        expect(described_class.normalize(:mood, "interjection")).to eq(["minor", :aliased])
      end
    end

    context "with Jaro-Winkler fuzzy fallback" do
      it "resolves typos of canonical moods with :fuzzy status" do
        expect(described_class.normalize(:mood, "declaritive")).to eq(["declarative", :fuzzy])
        expect(described_class.normalize(:mood, "imperitive")).to eq(["imperative", :fuzzy])
        expect(described_class.normalize(:mood, "interogative")).to eq(["interrogative", :fuzzy])
      end

      it "resolves a near-miss of an alias key through the alias table" do
        # "subjunctiv" isn't an alias itself; its best fuzzy hit is the
        # alias key "subjunctive", which maps to declarative.
        expect(described_class.normalize(:mood, "subjunctiv")).to eq(["declarative", :fuzzy])
      end

      it "resolves theme_type typos with :fuzzy status" do
        expect(described_class.normalize(:theme_type, "circumstancial")).to eq(["circumstantial", :fuzzy])
        expect(described_class.normalize(:theme_type, "predicatd")).to eq(["predicated", :fuzzy])
      end

      it "does not fuzzy-match unrelated grammar terms below the threshold" do
        # Worst measured near-collision: "performative"→"imperative"
        # scores 0.809, "infinitive"→"indicative" 0.802 — both must
        # fall through to the warned default, not silently rewrite.
        expect(described_class.normalize(:mood, "performative")).to eq(["declarative", :unknown])
        expect(described_class.normalize(:mood, "infinitive")).to eq(["declarative", :unknown])
        expect(described_class.normalize(:mood, "banana")).to eq(["declarative", :unknown])
      end

      it "skips fuzzy matching for strings shorter than FUZZY_MIN_LENGTH" do
        expect(described_class.normalize(:mood, "dec")).to eq(["declarative", :unknown])
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
