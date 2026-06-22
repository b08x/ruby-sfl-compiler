# frozen_string_literal: true

module SFL
  module Compiler
    module Analysis
      # Shared aggregation helpers for analyzers. Extracted from 4
      # independent copies (SpeakerProfiler, CorrelationAnalyzer,
      # ConversationAnalyzer, DocumentationAnalyzer) that had drifted:
      # two defaulted an empty collection to 0.0, two to 0.5, with
      # inconsistent rounding. Standardized on 0.5 — the same
      # neutral-midpoint default InterpersonalPayload's stub/fallback
      # values already use elsewhere for "no SFL signal available" — and
      # consistent 3-decimal rounding.
      module Aggregations
        def mean(values)
          return 0.5 if values.empty?

          (values.sum / values.size.to_f).round(3)
        end
      end
    end
  end
end
