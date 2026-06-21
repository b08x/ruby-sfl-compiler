# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::PassTwoEngine do
  let(:token) do
    SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
  end

  let(:clause) do
    SFL::Compiler::Types::SyntacticClause.new(
      id: "syn-1", text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: "doc-1"
    )
  end

  let(:ideational) do
    SFL::Compiler::Types::IdeationalPayload.new(
      clause_id: "syn-1", process_type: "material",
      participants: [], circumstances: [], raw_transitivity: {}
    )
  end

  describe "#annotate_batch" do
    def clause_pair(text, id)
      syntactic = SFL::Compiler::Types::SyntacticClause.new(
        id: id, text: text, tokens: [token],
        root_index: 0, sentence_index: 0, document_id: "doc-1"
      )
      payload = SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: id, process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      )
      [syntactic, payload]
    end

    let(:pairs) { (1..5).map { |i| clause_pair("Clause #{i}.", "syn-#{i}") } }

    def annotation_for(index, tenor: 0.8)
      {
        index: index,
        mood: "declarative",
        modality_weight: 0.9,
        tenor: tenor,
        speaker_attitude: "neutral",
        reasoning: "canned"
      }
    end

    it "annotates every clause in order via batched LLM calls" do
      annotator = lambda do |items|
        items.map { |item| annotation_for(item[:index], tenor: (item[:index] + 1) / 10.0) }
      end

      engine = described_class.new(batch_annotator: annotator)
      annotated = engine.annotate_batch(pairs, batch_size: 2, concurrency: 1)

      expect(annotated.map(&:text)).to eq(pairs.map { |syntactic, _| syntactic.text })
      expect(annotated.map { |a| a.interpersonal.tenor }).to eq([0.1, 0.2, 0.3, 0.4, 0.5])
      expect(annotated.map { |a| a.interpersonal.annotation_source }.uniq).to eq(["llm"])
    end

    it "splits work into batch_size chunks" do
      calls = Queue.new
      annotator = lambda do |items|
        calls << items.size
        items.map { |item| annotation_for(item[:index]) }
      end

      described_class.new(batch_annotator: annotator)
        .annotate_batch(pairs, batch_size: 2, concurrency: 1)

      sizes = Array.new(calls.size) { calls.pop }
      expect(sizes.sort).to eq([1, 2, 2])
    end

    it "falls back per clause when an annotation index is missing or invalid" do
      annotator = lambda do |items|
        items.filter_map do |item|
          next if item[:index] == 1                                  # missing
          next annotation_for(item[:index], tenor: 9.9) if item[:index] == 2 # out of range (clamped)
          annotation_for(item[:index])
        end
      end

      annotated = nil
      expect {
        annotated = described_class.new(batch_annotator: annotator)
          .annotate_batch(pairs, batch_size: 5, concurrency: 1)
      }.to output(/\[WARN\]/).to_stderr

      sources = annotated.map { |a| a.interpersonal.annotation_source }
      # Index 1 is missing → fallback; index 2 has out-of-range tenor (9.9) → clamped to 1.0 (llm)
      expect(sources).to eq(%w[llm fallback llm llm llm])
      expect(annotated[1].interpersonal.tenor).to eq(0.5)
      expect(annotated[2].interpersonal.tenor).to eq(1.0)
    end

    it "falls back for the whole chunk when its LLM call fails persistently, without affecting other chunks" do
      annotator = lambda do |items|
        raise StandardError, "boom" if items.any? { |item| item[:index].zero? }

        items.map { |item| annotation_for(item[:index]) }
      end

      annotated = nil
      expect {
        annotated = described_class.new(batch_annotator: annotator)
          .annotate_batch(pairs, batch_size: 3, concurrency: 1)
      }.to output(/\[WARN\]/).to_stderr

      sources = annotated.map { |a| a.interpersonal.annotation_source }
      expect(sources).to eq(%w[fallback fallback fallback llm llm])
    end

    it "retries a failed chunk once before falling back" do
      attempts = 0
      annotator = lambda do |items|
        attempts += 1
        raise StandardError, "transient" if attempts == 1

        items.map { |item| annotation_for(item[:index]) }
      end

      annotated = described_class.new(batch_annotator: annotator)
        .annotate_batch(pairs, batch_size: 5, concurrency: 1)

      expect(attempts).to eq(2)
      expect(annotated.map { |a| a.interpersonal.annotation_source }.uniq).to eq(["llm"])
    end

    it "preserves clause order when chunks run concurrently" do
      annotator = lambda do |items|
        sleep(rand / 50)
        items.map { |item| annotation_for(item[:index], tenor: (item[:index] + 1) / 10.0) }
      end

      annotated = described_class.new(batch_annotator: annotator)
        .annotate_batch(pairs, batch_size: 1, concurrency: 4)

      expect(annotated.map { |a| a.interpersonal.tenor }).to eq([0.1, 0.2, 0.3, 0.4, 0.5])
    end

    it "interrupts a hung LLM call after chunk_timeout and falls back" do
      annotator = lambda do |_items|
        sleep # a dead connection raises nothing — block forever
      end

      annotated = nil
      elapsed = nil
      expect {
        start = Time.now
        annotated = described_class.new(batch_annotator: annotator, chunk_timeout: 0.1)
          .annotate_batch(pairs, batch_size: 5, concurrency: 1)
        elapsed = Time.now - start
      }.to output(/\[WARN\]/).to_stderr

      expect(elapsed).to be < 2 # two attempts × 0.1s, not forever
      expect(annotated.map { |a| a.interpersonal.annotation_source }.uniq).to eq(["fallback"])
    end

    it "returns an empty array for empty input" do
      engine = described_class.new(batch_annotator: ->(_items) { [] })
      expect(engine.annotate_batch([])).to eq([])
    end
  end

  describe "annotation provenance" do
    it "marks successful annotations as llm-sourced" do
      breaker = lambda do |&_block|
        {
          mood: "interrogative",
          modality_weight: 0.9,
          tenor: 0.8,
          speaker_attitude: "neutral",
          reasoning: "canned"
        }
      end

      annotated = described_class.new(circuit_breaker: breaker).annotate(clause, ideational)

      expect(annotated.interpersonal.annotation_source).to eq("llm")
      expect(annotated.interpersonal.tenor).to eq(0.8)
    end

    it "marks defaulted annotations as fallback-sourced when the LLM call fails" do
      breaker = lambda { |&_block| raise StandardError, "boom" }

      annotated = nil
      expect {
        annotated = described_class.new(circuit_breaker: breaker).annotate(clause, ideational)
      }.to output(/\[WARN\] Pass 2/).to_stderr

      expect(annotated.interpersonal.annotation_source).to eq("fallback")
      expect(annotated.interpersonal.tenor).to eq(0.5)
      expect(annotated.interpersonal.modality_weight).to eq(0.5)
    end
  end
end
