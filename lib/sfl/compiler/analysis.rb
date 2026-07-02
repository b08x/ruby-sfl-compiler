# frozen_string_literal: true

require_relative "analysis/aggregations"
require_relative "analysis/chunk_artifact_detector"
require_relative "analysis/tenor_tracker"
require_relative "analysis/speaker_profiler"
require_relative "analysis/correlation_analyzer"
require_relative "analysis/cohesion_analyzer"
require_relative "analysis/topic_modeler"
require_relative "analysis/conversation_analyzer"
require_relative "analysis/documentation_analyzer"
require_relative "analysis/narrative_generator"
require_relative "analysis/citation_grounding_checker"
require_relative "analysis/narrative_self_analyzer"
require_relative "analysis/content_type_classifier"
require_relative "analysis/quality_scorer"
require_relative "analysis/migration_assessor"
require_relative "analysis/knowledge_base_analyzer"

module SFL
  module Compiler
    module Analysis
      # Analysis modules for conversation/document processing
    end
  end
end
