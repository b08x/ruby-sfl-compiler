# frozen_string_literal: true

require "csv"

module SFL
  module Compiler
    module Formatters
      # Exports a KnowledgeBaseReport to CSV — one row per artifact.
      class KBCsvFormatter < BaseFormatter
        HEADERS = %w[
          artifact_id title source_file section_path
          content_type quality_score migration_action
          tags last_updated llm_clause_count fallback_clause_count
        ].freeze

        def render
          CSV.generate do |csv|
            csv << HEADERS
            result.artifacts.each { |a| csv << artifact_to_row(a) }
          end
        end

        private def artifact_to_row(a)
          cov = a.annotation_coverage
          [
            a.artifact_id,
            a.title,
            a.source_file,
            a.section_path,
            a.content_type,
            a.quality_score.round(3),
            a.migration_action,
            a.tags.join("; "),
            a.last_updated&.strftime("%Y-%m-%d"),
            cov[:llm] || 0,
            cov[:fallback].to_i + cov[:stub].to_i,
          ]
        end
      end
    end
  end
end
