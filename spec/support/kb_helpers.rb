# frozen_string_literal: true

# Shared helpers for KB pipeline specs: builds lightweight AnnotatedClause
# objects with controllable SFL interpersonal/ideational properties.
module KBHelpers
  def make_clause(
    doc_id: "test#sec",
    mood: "declarative",
    modality_weight: 0.6,
    tenor: 0.5,
    process_type: "material",
    annotation_source: "llm"
  )
    token = SFL::Compiler::Types::SyntacticToken.new(
      text: "works", lemma: "work", pos: "VERB", tag: "VBZ",
      dep: "ROOT", head_index: -1, morphology: {}, index: 0
    )
    syntactic = SFL::Compiler::Types::SyntacticClause.new(
      id: SecureRandom.uuid, text: "It works.", tokens: [token],
      root_index: 0, sentence_index: 0, document_id: doc_id
    )
    SFL::Compiler::Types::AnnotatedClause.new(
      id: SecureRandom.uuid, text: "It works.", syntactic:,
      ideational: SFL::Compiler::Types::IdeationalPayload.new(
        clause_id: syntactic.id, process_type:,
        participants: [], circumstances: [], raw_transitivity: {}
      ),
      interpersonal: SFL::Compiler::Types::InterpersonalPayload.new(
        clause_id: syntactic.id, mood:, modality_weight:, tenor:,
        speaker_attitude: nil, reasoning: nil,
        annotation_source:
      ),
      document_id: doc_id, compiled_at: Time.now
    )
  end

  def make_section(text:, heading: "Section", frontmatter: nil)
    SFL::Compiler::MarkdownLoader::Section.new(
      document_id: "test#section",
      file_id: "test",
      heading:,
      heading_level: 1,
      heading_slug: "section",
      text:,
      byte_range: nil,
      frontmatter:
    )
  end
end
