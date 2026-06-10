# frozen_string_literal: true

require "journald/logger"

module SFL
  module Compiler
    # Ideational Extractor (Pass 1 post-processing)
    #
    # Maps syntactic dependency structures to SFL Ideational metafunction
    # categories: process type, participants (semantic roles), and
    # circumstances (adjuncts).
    #
    # This is a rule-based extraction that operates on the output of
    # PassOneEngine — no LLM calls. It uses dependency labels and POS
    # tags to classify transitivity.
    class IdeationalExtractor
      # spaCy dependency labels mapped to SFL participant roles
      PARTICIPANT_ROLES = {
        "nsubj" => "Actor",           # Subject of material process
        "nsubjpass" => "Goal",        # Passive subject
        "dobj" => "Goal",             # Direct object
        "iobj" => "Recipient",        # Indirect object
        "attr" => "Attribute",        # Attributive complement
        "oprd" => "Attribute",        # Object predicate
        "pobj" => "Circumstance",     # Object of preposition
        "prep" => "Circumstance",     # Prepositional modifier
        "advmod" => "Circumstance",   # Adverbial modifier
        "advcl" => "Circumstance",    # Adverbial clause modifier
        "acomp" => "Attribute",       # Adjectival complement
        "xcomp" => "Process",         # Open clausal complement
        "ccomp" => "Process",         # Clausal complement
        "conj" => "Participant",      # Conjunct
        "appos" => "Participant"      # Appositional modifier
      }.freeze

      # Verb POS tags that indicate process types
      PROCESS_INDICATORS = {
        "VB" => "material", "VBD" => "material", "VBG" => "material",
        "VBN" => "material", "VBP" => "material", "VBZ" => "material",
        # Modal auxiliaries (MD) don't define process type on their own —
        # the lexical verb complement does. Default to "mental" since modal
        # clauses are typically epistemic/deontic (mental/relational domain).
        "MD" => "mental"
      }.freeze

      def initialize
        @logger = Journald::Logger.new("sfl-compiler-ideational")
      end

      # Extract Ideational payload from a syntactic clause.
      #
      # @param clause [Types::SyntacticClause] Output from PassOneEngine
      # @return [Types::IdeationalPayload]
      def extract(clause)
        root_token = clause.tokens[clause.root_index]
        return empty_payload(clause.id) if root_token.nil?

        process_type = classify_process(root_token, clause)
        participants = extract_participants(clause)
        circumstances = extract_circumstances(clause)

        Types::IdeationalPayload.new(
          clause_id: clause.id,
          process_type: process_type,
          participants: participants,
          circumstances: circumstances,
          raw_transitivity: build_transitivity_hash(root_token, clause)
        )
      end

      private

      def classify_process(root_token, clause)
        tag = root_token.tag

        # Mental processes: cognition verbs
        if mental_verb?(root_token)
          "mental"
        # Relational processes: copular/linking verbs
        elsif relational_verb?(root_token)
          "relational"
        # Verbal processes: saying/telling verbs
        elsif verbal_verb?(root_token)
          "verbal"
        # Behavioral processes: physiological/psychological behavior
        elsif behavioral_verb?(root_token)
          "behavioral"
        # Existential: "there is/are"
        elsif existential?(root_token, clause)
          "existential"
        # Default: material (action)
        else
          PROCESS_INDICATORS.fetch(tag[0..1], "material")
        end
      end

      def mental_verb?(token)
        lemma = token.lemma.downcase
        %w[think know believe understand feel see hear want need like love hate
           consider suppose expect remember forget imagine notice realize].include?(lemma)
      end

      def relational_verb?(token)
        lemma = token.lemma.downcase
        %w[be seem become appear remain stay look sound taste smell feel].include?(lemma)
      end

      def verbal_verb?(token)
        lemma = token.lemma.downcase
        %w[say tell speak talk ask answer reply respond declare announce
           report explain suggest propose].include?(lemma)
      end

      def behavioral_verb?(token)
        lemma = token.lemma.downcase
        %w[breathe smile sneeze cry laugh look watch listen cough sleep].include?(lemma)
      end

      def existential?(token, clause)
        clause.text.strip.downcase.start_with?("there ") &&
          %w[be exist].include?(token.lemma.downcase)
      end

      def extract_participants(clause)
        clause.tokens.filter_map do |token|
          role = PARTICIPANT_ROLES[token.dep]
          if role && role != "Circumstance"
            Types::Participant.new(role: role, text: token.text)
          end
        end
      end

      def extract_circumstances(clause)
        clause.tokens.filter_map do |token|
          role = PARTICIPANT_ROLES[token.dep]
          next unless role == "Circumstance"

          "#{token.dep}:#{token.text}"
        end
      end

      def build_transitivity_hash(root_token, clause)
        {
          root: {
            text: root_token.text,
            lemma: root_token.lemma,
            pos: root_token.pos,
            tag: root_token.tag
          },
          dependencies: clause.tokens.map { |t|
            { text: t.text, dep: t.dep, pos: t.pos, tag: t.tag }
          }
        }
      end

      def empty_payload(clause_id)
        Types::IdeationalPayload.new(
          clause_id: clause_id,
          process_type: "material",
          participants: [],
          circumstances: [],
          raw_transitivity: {}
        )
      end
    end
  end
end
