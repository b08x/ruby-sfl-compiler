# frozen_string_literal: true

require "json"

module SFL
  module Compiler
    module Formatters
      # Exports a KnowledgeBaseReport to JSON.
      class KBJsonFormatter < BaseFormatter
        def render
          JSON.pretty_generate(build_hash)
        end

        private def build_hash
          {
            metadata:                   result.metadata,
            content_type_distribution:  result.content_type_distribution,
            quality_distribution:       result.quality_distribution,
            staleness_flags:            result.staleness_flags,
            migration_manifest:         format_manifest,
            artifacts:                  format_artifacts,
          }
        end

        private def format_manifest
          result.migration_manifest.map do |entry|
            {
              artifact_id:   entry.artifact_id,
              title:         entry.title,
              source_file:   entry.source_file,
              content_type:  entry.content_type,
              quality_score: entry.quality_score,
              action:        entry.action,
              reason:        entry.reason,
            }
          end
        end

        private def format_artifacts
          result.artifacts.map do |a|
            {
              artifact_id:        a.artifact_id,
              title:              a.title,
              source_file:        a.source_file,
              section_path:       a.section_path,
              content_type:       a.content_type,
              quality_score:      a.quality_score,
              migration_action:   a.migration_action,
              migration_reason:   a.migration_reason,
              tags:               a.tags,
              last_updated:       a.last_updated&.iso8601,
              avg_tenor:          a.avg_tenor,
              avg_modality:       a.avg_modality,
              dominant_mood:      a.dominant_mood,
              process_types:      a.process_types,
              annotation_coverage: a.annotation_coverage,
            }
          end
        end
      end
    end
  end
end
