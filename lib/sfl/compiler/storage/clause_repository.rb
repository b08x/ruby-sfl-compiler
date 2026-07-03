# frozen_string_literal: true

require "sequel"
require "circuit_breaker"
require "journald/logger"

module SFL
  module Compiler
    # Clause repository — CRUD for annotated clauses with payload separation.
    class ClauseRepository
      CLAUSE_LISTING_COLUMNS = [
        Sequel[:clauses][:external_id].as(:id),
        Sequel[:clauses][:text],
        Sequel[:clauses][:document_id],
        Sequel[:clauses][:source_type],
        Sequel[:clauses][:topic_id],
        Sequel[:clauses][:topic_label],
        Sequel[:ideational_payloads][:process_type],
        Sequel[:ideational_payloads][:participants],
        Sequel[:ideational_payloads][:circumstances],
        Sequel[:interpersonal_payloads][:mood],
        Sequel[:interpersonal_payloads][:modality_weight],
        Sequel[:interpersonal_payloads][:tenor],
        Sequel[:interpersonal_payloads][:speaker_attitude],
        Sequel[:interpersonal_payloads][:annotation_source],
      ].freeze

      # Same shape as CLAUSE_LISTING_COLUMNS plus the two columns the
      # review queue needs to render evidence that #find_all's callers
      # (the Corpus Browser) don't: the DSPy reasoning text and the
      # structured reasoning_trace (premises/inference_rule/confidence).
      REVIEW_QUEUE_COLUMNS = (CLAUSE_LISTING_COLUMNS + [
        Sequel[:interpersonal_payloads][:reasoning],
        Sequel[:interpersonal_payloads][:reasoning_trace],
      ]).freeze

      def initialize(db)
        @db = db
        @logger = Journald::Logger.new("sfl-compiler-repo")
      end

      # Store a fully annotated clause with separated payloads.
      #
      # @param annotated [Types::AnnotatedClause]
      # @param topic [Hash, nil] { id:, label: } from a pre-pass TopicModeler
      #   fit over the clause's document/section — nil when topic modeling
      #   wasn't requested.
      # @param source_type [String, nil] provenance tag (e.g. "chat_native",
      #   "chat_claude", "vault_markdown", "vault_pdf", "api") distinguishing
      #   which ingest path produced this clause — nil stores the column's
      #   own "unspecified" default rather than a Ruby-side literal, so a
      #   schema-level rename only has to happen in one place.
      # @return [String] The stored clause external_id
      def store(annotated, topic: nil, source_type: nil)
        @db.transaction do
          # Store base clause
          insert = {
            external_id: annotated.id,
            text: annotated.text,
            document_id: annotated.document_id,
            sentence_index: annotated.syntactic.sentence_index,
            tokens: Sequel.pg_jsonb(annotated.syntactic.tokens.map(&:to_h)),
            root_token: Sequel.pg_jsonb(
              annotated.syntactic.tokens[annotated.syntactic.root_index].to_h
            ),
            topic_id: topic&.fetch(:id, nil),
            topic_label: topic&.fetch(:label, nil),
            created_at: Time.now
          }
          insert[:source_type] = source_type if source_type
          @db[:clauses].insert(insert)

          # Store Ideational payload (from Pass 1)
          @db[:ideational_payloads].insert(
            clause_id: annotated.id,
            process_type: annotated.ideational.process_type,
            participants: Sequel.pg_jsonb(annotated.ideational.participants.map(&:to_h)),
            circumstances: Sequel.pg_jsonb(annotated.ideational.circumstances),
            raw_transitivity: Sequel.pg_jsonb(annotated.ideational.raw_transitivity),
            created_at: Time.now
          )

          # Store Interpersonal payload (from Pass 2)
          @db[:interpersonal_payloads].insert(
            clause_id: annotated.id,
            mood: annotated.interpersonal.mood,
            modality_weight: annotated.interpersonal.modality_weight,
            tenor: annotated.interpersonal.tenor,
            speaker_attitude: annotated.interpersonal.speaker_attitude,
            reasoning: annotated.interpersonal.reasoning,
            annotation_source: annotated.interpersonal.annotation_source,
            reasoning_trace: reasoning_trace_jsonb(annotated.interpersonal.reasoning_trace),
            created_at: Time.now
          )
        end

        @logger.send_message(
          message: "clause_stored",
          priority: Journald::LOG_INFO,
          clause_id: annotated.id,
          document_id: annotated.document_id,
          process_type: annotated.ideational.process_type,
          mood: annotated.interpersonal.mood
        )

        annotated.id
      rescue Sequel::DatabaseError => e
        @logger.send_message(
          message: "clause_store_failed",
          priority: Journald::LOG_ERR,
          clause_id: annotated.id,
          error: e.message
        )
        raise
      end

      # Remove every clause (and its payload/embedding rows) previously
      # stored for a document. Clause external_ids are fresh UUIDs on every
      # compile, so re-ingesting without this silently duplicates content;
      # callers delete-then-store to make ingestion idempotent per document.
      #
      # @param document_id [String]
      # @return [Integer] number of clauses removed
      def delete_by_document(document_id)
        @db.transaction do
          scoped = @db[:clauses].where(document_id:)
          clause_ids = scoped.select_map(:external_id)
          break 0 if clause_ids.empty?

          @db[:ideational_payloads].where(clause_id: clause_ids).delete
          @db[:interpersonal_payloads].where(clause_id: clause_ids).delete
          @db[:embeddings].where(clause_id: clause_ids).delete
          scoped.delete
        end
      end

      # Retrieve an annotated clause by ID with all payloads.
      #
      # @param clause_id [String]
      # @return [Hash, nil]
      def find(clause_id)
        clause = @db[:clauses].where(external_id: clause_id).first
        return nil unless clause

        ideational = @db[:ideational_payloads].where(clause_id:).first
        interpersonal = @db[:interpersonal_payloads].where(clause_id:).first
        embedding = @db[:embeddings].where(clause_id:).first

        {
          clause:,
          ideational:,
          interpersonal:,
          embedding:,
        }
      end

      # Find clauses by scalar interpersonal filters.
      #
      # @param mood [String, nil] Filter by mood type
      # @param min_modality [Float, nil] Minimum modality weight
      # @param max_modality [Float, nil] Maximum modality weight
      # @param min_tenor [Float, nil] Minimum tenor (formality)
      # @param max_tenor [Float, nil] Maximum tenor
      # @param limit [Integer] Max results
      # @return [Array<Hash>]
      def find_by_interpersonal(
        mood: nil,
        min_modality: nil, max_modality: nil,
        min_tenor: nil, max_tenor: nil,
        limit: 50
      )
        ds = @db[:clauses]
          .join(:interpersonal_payloads, clause_id: :external_id)

        ds = ds.where(mood:) if mood
        ds = ds.where { modality_weight >= min_modality } if min_modality
        ds = ds.where { modality_weight <= max_modality } if max_modality
        ds = ds.where { tenor >= min_tenor } if min_tenor
        ds = ds.where { tenor <= max_tenor } if max_tenor

        ds.limit(limit).all
      end

      # Find clauses by Ideational process type.
      #
      # @param process_type [String] One of: material, mental, relational, verbal, behavioral, existential
      # @param limit [Integer]
      # @return [Array<Hash>]
      def find_by_process_type(process_type, limit: 50)
        @db[:clauses]
          .join(:ideational_payloads, clause_id: :external_id)
          .where(process_type:)
          .limit(limit)
          .all
      end

      # Reconstruct a stored clause's Pass 1 output (Types::SyntacticClause
      # + Types::IdeationalPayload) so PassTwoEngine#annotate can be re-run
      # against it without a fresh spaCy pass — the re-annotation path's
      # only way to get typed structs back out of the DB's jsonb columns.
      #
      # Jsonb payloads round-trip through Postgres with STRING keys
      # (verified live against a real DB before writing this — unlike the
      # Ruby-side structs' own symbol-keyed #to_h that went in), so token/
      # participant hashes are read with string indexing here, not the
      # symbol indexing #store's own callers use.
      #
      # clauses stores a root_token snapshot, not the tokens array
      # position — root_index is recomputed the same way PassOneEngine
      # originally derived it (first token whose dep is "ROOT").
      #
      # @param clause_id [String]
      # @return [Hash{syntactic:, ideational:}, nil] nil if the clause or
      #   its ideational payload no longer exists
      def find_pass_one_output(clause_id)
        clause = @db[:clauses].where(external_id: clause_id).first
        return nil unless clause

        ideational = @db[:ideational_payloads].where(clause_id:).first
        return nil unless ideational

        { syntactic: reconstruct_syntactic(clause), ideational: reconstruct_ideational(ideational, clause_id) }
      end

      # Overwrite one clause's interpersonal_payloads row after a
      # human-triggered re-annotation. Unlike #store (insert-only,
      # clause_id has a unique index), this updates the existing row in
      # place — a clause is re-annotated, never duplicated.
      #
      # @param clause_id [String]
      # @param interpersonal [Types::InterpersonalPayload]
      # @return [Integer] rows updated (0 if the clause has no row yet)
      def update_interpersonal(clause_id, interpersonal)
        @db[:interpersonal_payloads].where(clause_id:).update(
          mood: interpersonal.mood,
          modality_weight: interpersonal.modality_weight,
          tenor: interpersonal.tenor,
          speaker_attitude: interpersonal.speaker_attitude,
          reasoning: interpersonal.reasoning,
          annotation_source: interpersonal.annotation_source,
          reasoning_trace: reasoning_trace_jsonb(interpersonal.reasoning_trace)
        )
      end

      # Persist a human review decision as an audit-trail row. Does not
      # mutate interpersonal_payloads itself — flipping annotation_source
      # to "human" happens where new values actually get written (the
      # re-annotation path, a separate card), not here. This method's job
      # is only to make the decision durable and attributable.
      #
      # @param clause_id [String]
      # @param decision [String] one of Types::ReviewDecision
      # @param original_annotation_source [String] the clause's
      #   annotation_source at the moment of decision, snapshotted so the
      #   audit trail survives later re-annotation overwriting it
      # @param reviewer [String, nil]
      # @param notes [String, nil]
      # @return [Types::AnnotationReview]
      def record_review(clause_id:, decision:, original_annotation_source:, reviewer: nil, notes: nil)
        review = Types::AnnotationReview.new(
          clause_id:, decision:, original_annotation_source:, reviewer:, notes:
        )
        @db[:annotation_reviews].insert(review_row(review))
        review
      end

      private def review_row(review)
        {
          id: review.id,
          clause_id: review.clause_id,
          decision: review.decision,
          original_annotation_source: review.original_annotation_source,
          reviewer: review.reviewer,
          notes: review.notes,
          reviewed_at: review.reviewed_at,
          created_at: Time.now
        }
      end

      # @param clause_id [String]
      # @return [Array<Hash>] review rows for a clause, oldest first
      def reviews_for(clause_id)
        @db[:annotation_reviews].where(clause_id:).order(:reviewed_at).all
      end

      # Scalar filter => how to apply it against the joined scope. Each
      # value is a 1-arity proc: given the raw filter value, returns
      # something #where can consume (a Hash-style equality condition or
      # a block-friendly Sequel expression). Table-qualified throughout
      # since both payload tables are joined into the same query.
      FIND_ALL_FILTERS = {
        document_id: ->(v) { { Sequel[:clauses][:document_id] => v } },
        source_type: ->(v) { { Sequel[:clauses][:source_type] => v } },
        annotation_source: ->(v) { { Sequel[:interpersonal_payloads][:annotation_source] => v } },
        mood: ->(v) { { Sequel[:interpersonal_payloads][:mood] => v } },
        process_type: ->(v) { { Sequel[:ideational_payloads][:process_type] => v } },
        min_modality: ->(v) { Sequel[:interpersonal_payloads][:modality_weight] >= v },
        max_modality: ->(v) { Sequel[:interpersonal_payloads][:modality_weight] <= v },
        min_tenor: ->(v) { Sequel[:interpersonal_payloads][:tenor] >= v },
        max_tenor: ->(v) { Sequel[:interpersonal_payloads][:tenor] <= v },
      }.freeze

      # Paginated, multi-filter clause listing for the Corpus Browser —
      # unlike HybridRetriever#retrieve (a ranked search result over a
      # query string), this is a plain filtered scan with no ranking, for
      # browsing a document's clauses page by page. Joins both payload
      # tables in one query (verified against a real DB before writing
      # this — Sequel's join-condition hash needs each new table's join
      # explicitly qualified against Sequel[:clauses][:external_id],
      # otherwise "clause_id"/"external_id" are ambiguous once two
      # payload tables are both in the FROM clause).
      #
      # @param filters [Hash] any of FIND_ALL_FILTERS.keys => value
      # @param limit [Integer]
      # @param offset [Integer]
      # @return [Hash] { clauses: Array<Hash>, total: Integer }
      def find_all(filters: {}, limit: 50, offset: 0)
        scope = filtered_scope(filters)

        total = scope.count
        rows = scope
          .order(Sequel[:clauses][:created_at])
          .limit(limit, offset)
          .select(*CLAUSE_LISTING_COLUMNS)
          .all

        { clauses: rows, total: }
      end

      # The HITL review queue: clauses whose annotation_source isn't
      # trusted (mirrors TUI::EvidencePane#flagged_section's predicate —
      # anything the pipeline couldn't confidently annotate on its own),
      # excluding clauses a human has already accepted as-is — otherwise
      # "Accept" (which deliberately leaves annotation_source untouched;
      # see #record_review) would never actually clear an item from the
      # queue, and a human would have to re-decide the same clause every
      # time the queue reloads. Live-verified this was a real bug, not a
      # hypothetical: accepting a stub clause through the React review
      # queue left it reappearing on refresh until this exclusion was
      # added. "rejected" does NOT exclude — an unresolved disagreement
      # should keep showing up.
      #
      # "fuzzy" classification-gap provenance (Jaro-Winkler near-misses,
      # PassTwoEngine#log_classification_gap) is NOT included here — it's
      # only ever logged (stderr/journald), never attached to the stored
      # payload, so there is nothing in the DB to surface yet.
      #
      # @param limit [Integer]
      # @param offset [Integer]
      # @return [Hash] { clauses: Array<Hash>, total: Integer }
      def review_queue(limit: 50, offset: 0)
        scope = needs_attention_scope
          .exclude(Sequel[:clauses][:external_id] => accepted_clause_ids)

        total = scope.count
        rows = scope
          .order(Sequel[:clauses][:created_at])
          .limit(limit, offset)
          .select(*REVIEW_QUEUE_COLUMNS)
          .all

        { clauses: rows, total: }
      end

      private def needs_attention_scope
        @db[:clauses]
          .join(:ideational_payloads, clause_id: Sequel[:clauses][:external_id])
          .join(:interpersonal_payloads, clause_id: Sequel[:clauses][:external_id])
          .exclude(Sequel[:interpersonal_payloads][:annotation_source] => Types::TRUSTED_ANNOTATION_SOURCES)
      end

      private def accepted_clause_ids
        @db[:annotation_reviews].where(decision: "accepted").select(:clause_id)
      end

      private def filtered_scope(filters)
        scope = @db[:clauses]
          .join(:ideational_payloads, clause_id: Sequel[:clauses][:external_id])
          .join(:interpersonal_payloads, clause_id: Sequel[:clauses][:external_id])

        filters.each do |key, value|
          build = FIND_ALL_FILTERS[key]
          next unless build && value

          scope = scope.where(build.call(value))
        end

        scope
      end

      private def reconstruct_syntactic(clause)
        tokens = Array(clause[:tokens]).map { |t| reconstruct_token(t) }
        Types::SyntacticClause.new(
          id: clause[:external_id],
          text: clause[:text],
          tokens:,
          root_index: tokens.index { |t| t.dep == "ROOT" } || 0,
          sentence_index: clause[:sentence_index],
          document_id: clause[:document_id]
        )
      end

      private def reconstruct_token(token_hash)
        Types::SyntacticToken.new(
          text: token_hash["text"], lemma: token_hash["lemma"], pos: token_hash["pos"], tag: token_hash["tag"],
          dep: token_hash["dep"], head_index: token_hash["head_index"],
          morphology: (token_hash["morphology"] || {}).to_h, index: token_hash["index"]
        )
      end

      # Postgres jsonb columns come back as Sequel::Postgres::JSONBArray/
      # JSONBHash — Array/Hash-like, but not `instance_of?(Array)`/`Hash`,
      # which Dry::Types' strict Array()/Hash type checks require (verified
      # live: constructing IdeationalPayload from an unconverted JSONBArray
      # raises Dry::Struct::Error). Array()/#to_h coerce to the plain types.
      private def reconstruct_ideational(row, clause_id)
        Types::IdeationalPayload.new(
          clause_id:,
          participants: Array(row[:participants]).map { |p| Types::Participant.new(role: p["role"], text: p["text"]) },
          circumstances: Array(row[:circumstances]),
          raw_transitivity: (row[:raw_transitivity] || {}).to_h,
          process_type: row[:process_type]
        )
      end

      # nil stays nil (SQL NULL), not a stored JSON "null" — most clauses
      # (fallback/stub/human) carry no derivation to show.
      private def reasoning_trace_jsonb(reasoning_trace)
        return nil unless reasoning_trace

        Sequel.pg_jsonb(Types.dump(reasoning_trace))
      end
    end
  end
end
