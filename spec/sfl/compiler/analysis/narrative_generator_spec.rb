# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe SFL::Compiler::Analysis::NarrativeGenerator do
  def annotated_clause(source)
    token = SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
    syntactic = SFL::Compiler::Types::SyntacticClause.new(
      id: "syn-1", text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: "doc-1"
    )
    SFL::Compiler::Types::AnnotatedClause.new(
      id: SecureRandom.uuid, text: "It works.",
      syntactic: syntactic,
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: "syn-1", process_type: "material",
        participants: [], circumstances: [], raw_transitivity: {}
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: "syn-1", mood: "declarative", modality_weight: 0.7,
        tenor: 0.6, speaker_attitude: nil, reasoning: nil,
        annotation_source: source
      ),
      document_id: "doc-1", compiled_at: Time.now
    )
  end

  def turn(id, speaker, sources:, text: "Linearity isn't the enemy here.", semantic_coherence_score: nil)
    SFL::Compiler::Types::ConversationTurn.new(
      turn_id: id, speaker: speaker, timestamp: Time.at(1_700_000_000 + id),
      message_text: text, clauses: sources.map { |s| annotated_clause(s) },
      avg_tenor: 0.6, avg_modality: 0.7, dominant_mood: "declarative",
      process_types: { "material" => 1 }, participants: [], tenor_shift: nil,
      semantic_coherence_score: semantic_coherence_score
    )
  end

  let(:result) do
    SFL::Compiler::Types::AnalysisResult.new(
      metadata: { conversation_id: "conv-1", turn_count: 2, speakers: %w[A B] },
      turns: [
        turn(1, "A", sources: %w[llm llm]),
        turn(2, "B", sources: %w[fallback fallback fallback llm])
      ],
      speaker_profiles: {},
      tenor_timeline: [], field_evolution: [],
      correlations: { "material" => { count: 6, avg_tenor: 0.6, avg_modality: 0.7 } },
      insights: ["A contributed 1 of 2 turns"]
    )
  end

  let(:result_with_moments) do
    SFL::Compiler::Types::AnalysisResult.new(
      metadata: { conversation_id: "conv-2", turn_count: 2, speakers: %w[A B] },
      turns: [
        turn(1, "A", sources: %w[llm llm], semantic_coherence_score: 0.85),
        turn(2, "B", sources: %w[llm], semantic_coherence_score: nil)
      ],
      speaker_profiles: {},
      tenor_timeline: [], field_evolution: [],
      correlations: { "material" => { count: 6, avg_tenor: 0.6, avg_modality: 0.7 } },
      insights: ["A contributed 1 of 2 turns"],
      key_moments: [
        SFL::Compiler::Types::KeyMoment.new(
          turn_id: 1,
          type: "semantic_anomaly",
          magnitude: 0.9,
          description: "A sudden topic shift."
        )
      ]
    )
  end

  describe described_class::Digest do
    describe ".from_result" do
      it "includes per-turn previews and provenance counts in the text" do
        text = described_class.from_result(result).to_text
        expect(text).to include("Linearity isn't the enemy")
        expect(text).to include("conv-1")
      end

      it "marks turns with >50% defaulted clauses UNRELIABLE" do
        text = described_class.from_result(result).to_text
        expect(text).to match(/turn 2.*UNRELIABLE \(75% fallback\)/i)
        expect(text).not_to match(/turn 1.*UNRELIABLE/i)
      end

      it "includes semantic coherence score and key moments when present" do
        text = described_class.from_result(result_with_moments).to_text
        expect(text).to include("coherence=0.85")
        expect(text).not_to include("coherence=nil")
        expect(text).not_to include("turn 2 [B] mood=declarative tenor=0.6 modality=0.7 shift=nil clauses=1 defaulted=0 coherence=")
        expect(text).to include("== KEY MOMENTS ==")
        expect(text).to include("[semantic_anomaly] turn 1 (magnitude: 0.9) — A sudden topic shift.")
      end

      it "omits the low-confidence warning when metadata carries no such flag" do
        text = described_class.from_result(result).to_text
        expect(text).not_to include("LOW CONFIDENCE WARNING")
      end

      it "opens with a low-confidence warning naming the clause count and threshold when flagged" do
        low_confidence_result = result.new(metadata: result.metadata.merge(
          low_confidence: true, clause_count: 29, low_confidence_threshold: 30
        ))
        text = described_class.from_result(low_confidence_result).to_text

        expect(text).to start_with("== LOW CONFIDENCE WARNING ==")
        expect(text).to include("only 29 clauses (minimum 30 recommended)")
      end
    end

    describe ".from_json" do
      it "produces identical text to from_result for the same analysis" do
        json = SFL::Compiler::Formatters::JSONFormatter.new(result).render
        from_json = described_class.from_json(JSON.parse(json)).to_text
        from_result = described_class.from_result(result).to_text
        expect(from_json).to eq(from_result)
      end

      it "stays equivalent with populated speaker profiles" do
        profile = SFL::Compiler::Types::SpeakerProfile.new(
          speaker_name: "A", turn_count: 1, avg_tenor: 0.6,
          tenor_range: [0.5, 0.7], tenor_variance: 0.01, avg_modality: 0.7,
          mood_distribution: { "declarative" => 1.0 },
          dominant_processes: { "material" => 2 }
        )
        with_profiles = result.new(speaker_profiles: { "A" => profile })

        json = SFL::Compiler::Formatters::JSONFormatter.new(with_profiles).render
        expect(described_class.from_json(JSON.parse(json)).to_text)
          .to eq(described_class.from_result(with_profiles).to_text)
      end

      it "produces identical text for result with key moments and coherence" do
        json = SFL::Compiler::Formatters::JSONFormatter.new(result_with_moments).render
        from_json = described_class.from_json(JSON.parse(json)).to_text
        from_result = described_class.from_result(result_with_moments).to_text
        expect(from_json).to eq(from_result)
      end

      it "raises NarrativeError when turns are absent" do
        expect {
          described_class.from_json({ "metadata" => {} })
        }.to raise_error(SFL::Compiler::NarrativeError, /turns.*re-run/i)
      end

      it "raises NarrativeError naming a missing turn key" do
        bad = { "metadata" => {}, "turns" => [{ "turn_id" => 1 }] }
        expect {
          described_class.from_json(bad)
        }.to raise_error(SFL::Compiler::NarrativeError, /speaker/)
      end
    end
  end

  describe "#generate" do
    let(:digest) { described_class::Digest.from_result(result) }

    let(:canned_sections) do
      { overview: "An overview.", cast_and_roles: "Cast.",
        interpersonal_dynamics: "Dynamics.", conversational_arc: "Arc.",
        data_quality: "Quality.", takeaways: "Takeaways." }
    end

    it "passes the digest text to the narrator and assembles a NarrativeReport" do
      received = nil
      narrator = lambda { |text| received = text; canned_sections }

      report = described_class.new(narrator: narrator).generate(digest)

      expect(received).to eq(digest.to_text)
      expect(report).to be_a(SFL::Compiler::Types::NarrativeReport)
      expect(report.source).to eq("conv-1")
      expect(report.overview).to eq("An overview.")
    end

    it "raises NarrativeError when the narrator output is missing a section" do
      narrator = ->(_text) { canned_sections.except(:takeaways) }
      expect {
        described_class.new(narrator: narrator).generate(digest)
      }.to raise_error(SFL::Compiler::NarrativeError, /takeaways|missing/i)
    end

    it "raises NarrativeError when the narrator itself fails" do
      narrator = ->(_text) { raise StandardError, "provider exploded" }
      expect {
        described_class.new(narrator: narrator).generate(digest)
      }.to raise_error(SFL::Compiler::NarrativeError, /provider exploded/)
    end
  end
end

RSpec.describe SFL::Compiler::Analysis::MultiModelNarrator do
  let(:gen_model) { "openrouter/anthropic/claude-haiku-4" }
  let(:ver_model) { "openrouter/anthropic/claude-sonnet-4-5" }

  # Canned DSPy result doubles — respond to public_send for any section key.
  def propose_result(draft: "A draft narrative.", claims: "1. Claim A")
    obj = Object.new
    obj.define_singleton_method(:narrative_draft) { draft }
    obj.define_singleton_method(:claims)          { claims }
    obj
  end

  def challenge_result(coverage:, challenges: "")
    obj = Object.new
    obj.define_singleton_method(:citation_coverage) { coverage }
    obj.define_singleton_method(:challenges)        { challenges }
    obj
  end

  def verify_result(sections = {})
    defaults = {
      overview: "Overview.", cast_and_roles: "Cast.",
      interpersonal_dynamics: "Dynamics.", conversational_arc: "Arc.",
      data_quality: "Quality.", takeaways: "Takeaways.",
    }
    merged = defaults.merge(sections)
    obj = Object.new
    merged.each { |k, v| obj.define_singleton_method(k) { v } }
    obj
  end

  describe ".new" do
    it "raises ArgumentError when generation_model and verification_model are identical" do
      expect {
        described_class.new(generation_model: gen_model, verification_model: gen_model)
      }.to raise_error(ArgumentError, /must differ/)
    end

    it "accepts distinct models without raising" do
      expect {
        described_class.new(generation_model: gen_model, verification_model: ver_model)
      }.not_to raise_error
    end
  end

  describe "#call" do
    let(:digest_text) { "== METADATA ==\nconversation_id: test" }

    def stub_predictors(narrator, propose_results:, challenge_results:, verify_result: nil)
      call_idx_propose   = -1
      call_idx_challenge = -1

      allow(narrator).to receive(:run_achilles) do
        call_idx_propose += 1
        propose_results[call_idx_propose] || propose_results.last
      end

      allow(narrator).to receive(:run_tortoise) do |_digest, _draft|
        call_idx_challenge += 1
        challenge_results[call_idx_challenge] || challenge_results.last
      end

      allow(narrator).to receive(:finalize) do |_digest, _draft, _challenges|
        SFL::Compiler::Analysis::NarrativeGenerator::SECTION_KEYS
          .to_h { |k| [k, (verify_result || self.verify_result).public_send(k)] }
      end
    end

    it "returns sections directly when citation_coverage meets threshold on first attempt" do
      narrator = described_class.new(generation_model: gen_model, verification_model: ver_model)
      allow(narrator).to receive(:run_achilles).and_return(propose_result)
      allow(narrator).to receive(:run_tortoise).and_return(challenge_result(coverage: 0.9))
      allow(narrator).to receive(:finalize).and_return(
        SFL::Compiler::Analysis::NarrativeGenerator::SECTION_KEYS.to_h { |k| [k, k.to_s] }
      )

      result = narrator.call(digest_text)

      expect(narrator).to have_received(:run_achilles).once
      expect(narrator).to have_received(:finalize).once
      expect(result[:overview]).to eq("overview")
    end

    it "re-runs Achilles when citation_coverage is below threshold, succeeds on second attempt" do
      narrator = described_class.new(generation_model: gen_model, verification_model: ver_model)
      allow(narrator).to receive(:run_achilles).and_return(propose_result)
      allow(narrator).to receive(:run_tortoise)
        .and_return(challenge_result(coverage: 0.5), challenge_result(coverage: 0.85))
      allow(narrator).to receive(:finalize).and_return(
        SFL::Compiler::Analysis::NarrativeGenerator::SECTION_KEYS.to_h { |k| [k, "final"] }
      )

      result = narrator.call(digest_text)

      expect(narrator).to have_received(:run_achilles).twice
      expect(narrator).to have_received(:finalize).once
      expect(result[:takeaways]).to eq("final")
    end

    it "falls back to best-effort after max attempts and appends warning to data_quality" do
      narrator = described_class.new(generation_model: gen_model, verification_model: ver_model)
      allow(narrator).to receive(:run_achilles).and_return(propose_result)
      allow(narrator).to receive(:run_tortoise).and_return(challenge_result(coverage: 0.3))
      allow(narrator).to receive(:finalize).and_return(
        SFL::Compiler::Analysis::NarrativeGenerator::SECTION_KEYS.to_h do |k|
          [k, k == :data_quality ? "Annotation notes." : "content"]
        end
      )

      result = narrator.call(digest_text)

      expect(narrator).to have_received(:run_achilles)
        .exactly(SFL::Compiler::Analysis::MultiModelNarrator::MAX_ATTEMPTS).times
      expect(result[:data_quality]).to include("Low citation coverage")
      expect(result[:data_quality]).to include("Annotation notes.")
    end
  end
end
