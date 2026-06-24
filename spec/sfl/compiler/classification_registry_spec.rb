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

      it "respects existing aliases like topical_unmarked" do
        expect(described_class.normalize(:theme_type, "topical_unmarked")).to eq(["topical", :aliased])
      end

      it "handles prefix/suffix stripping correctly" do
        expect(described_class.normalize(:theme_type, "textual_theme")).to eq(["textual", :exact])
        expect(described_class.normalize(:theme_type, "theme_unmarked")).to eq(["unmarked", :exact])
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
