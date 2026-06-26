# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Analysis::ContentTypeClassifier do
  subject(:classifier) { described_class.new }

  # Long-enough text to clear the stub_section? guard (>250 chars).
  let(:prose) { "This is substantial prose content. " * 10 }

  describe "#classify" do
    context "image frontmatter sentinel" do
      it "returns :image when frontmatter has content_type = 'image'" do
        fm = { "content_type" => "image", "source_path" => "/img.png" }
        expect(classifier.classify(section: make_section(text: ""), clauses: [], frontmatter: fm))
          .to eq(:image)
      end
    end

    context "AI disclaimer detection" do
      it "returns :ai_generated when text contains the AI disclaimer phrase" do
        text = "Summary follows. AI responses may include mistakes. Please verify."
        expect(classifier.classify(section: make_section(text:), clauses: []))
          .to eq(:ai_generated)
      end

      it "is case-insensitive for the disclaimer" do
        text = "AI Responses May Include Mistakes in this output."
        expect(classifier.classify(section: make_section(text:), clauses: []))
          .to eq(:ai_generated)
      end
    end

    context "frontmatter tag matching" do
      it "returns :draft for a 'draft' tag" do
        fm = { "tags" => ["draft", "project"] }
        expect(classifier.classify(section: make_section(text: prose), clauses: [], frontmatter: fm))
          .to eq(:draft)
      end

      it "returns :draft for a 'wip' tag" do
        fm = { "tags" => ["wip"] }
        expect(classifier.classify(section: make_section(text: prose), clauses: [], frontmatter: fm))
          .to eq(:draft)
      end

      it "returns :tutorial for a 'tutorial' tag" do
        fm = { "tags" => ["tutorial", "ruby"] }
        expect(classifier.classify(section: make_section(text: prose), clauses: [], frontmatter: fm))
          .to eq(:tutorial)
      end

      it "returns :tutorial for a 'how-to' tag" do
        fm = { "tags" => ["how-to"] }
        expect(classifier.classify(section: make_section(text: prose), clauses: [], frontmatter: fm))
          .to eq(:tutorial)
      end

      it "returns :technical_reference for a 'reference' tag" do
        fm = { "tags" => ["reference"] }
        expect(classifier.classify(section: make_section(text: prose), clauses: [], frontmatter: fm))
          .to eq(:technical_reference)
      end

      it "returns :research_note for a 'research' tag" do
        fm = { "tags" => ["research", "nlp"] }
        expect(classifier.classify(section: make_section(text: prose), clauses: [], frontmatter: fm))
          .to eq(:research_note)
      end

      it "matches tags case-insensitively" do
        fm = { "tags" => ["Draft"] }
        expect(classifier.classify(section: make_section(text: prose), clauses: [], frontmatter: fm))
          .to eq(:draft)
      end

      it "AI disclaimer takes priority over a draft tag" do
        fm = { "tags" => ["draft"] }
        text = "AI responses may include mistakes. #{prose}"
        expect(classifier.classify(section: make_section(text:), clauses: [], frontmatter: fm))
          .to eq(:ai_generated)
      end
    end

    context "code-heaviness heuristic" do
      it "returns :code_snippet when more than 25% of content is in backtick spans" do
        # Build a string where code chars clearly exceed 25% + 80 char minimum
        code = "`some_method_call`" * 10  # 180 code chars
        plain = "a " * 5
        text = "#{plain} #{code}"
        expect(classifier.classify(section: make_section(text:), clauses: []))
          .to eq(:code_snippet)
      end

      it "does not flag code_snippet when code chars are below the minimum threshold" do
        text = "Just one `word` in backticks. " * 10
        # code_chars < MIN_CODE_CHARS (80) so heuristic is skipped
        result = classifier.classify(section: make_section(text:), clauses: [])
        expect(result).not_to eq(:code_snippet)
      end
    end

    context "stub/index detection" do
      it "returns :index for very short sections with 0 or 1 clauses" do
        expect(classifier.classify(section: make_section(text: "Brief."), clauses: []))
          .to eq(:index)
      end

      it "does not flag as :index when text is long even with few clauses" do
        result = classifier.classify(section: make_section(text: prose), clauses: [])
        expect(result).not_to eq(:index)
      end
    end

    context "SFL signal fallback" do
      it "returns :technical_reference for high-modality declarative clauses" do
        clauses = Array.new(5) do
          make_clause(modality_weight: 0.85, mood: "declarative", process_type: "relational")
        end
        expect(classifier.classify(section: make_section(text: prose), clauses:))
          .to eq(:technical_reference)
      end

      it "returns :tutorial for imperative material-process clauses" do
        clauses = Array.new(5) do
          make_clause(modality_weight: 0.4, mood: "imperative", process_type: "material")
        end
        expect(classifier.classify(section: make_section(text: prose), clauses:))
          .to eq(:tutorial)
      end

      it "returns :research_note for dominant mental-process clauses" do
        clauses = Array.new(5) do
          make_clause(modality_weight: 0.5, mood: "declarative", process_type: "mental")
        end
        expect(classifier.classify(section: make_section(text: prose), clauses:))
          .to eq(:research_note)
      end

      it "defaults to :research_note when no SFL signal is strong enough" do
        clauses = Array.new(5) do
          make_clause(modality_weight: 0.3, mood: "declarative", process_type: "behavioral")
        end
        expect(classifier.classify(section: make_section(text: prose), clauses:))
          .to eq(:research_note)
      end

      it "defaults to :research_note when clauses array is empty and text is long" do
        expect(classifier.classify(section: make_section(text: prose), clauses: []))
          .to eq(:research_note)
      end
    end
  end
end
