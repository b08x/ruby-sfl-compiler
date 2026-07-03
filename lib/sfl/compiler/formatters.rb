# frozen_string_literal: true

require_relative "formatters/base_formatter"
require_relative "formatters/csv_formatter"
require_relative "formatters/json_formatter"
require_relative "formatters/markdown_formatter"
require_relative "formatters/narrative_formatter"
require_relative "formatters/report_writer"
require_relative "formatters/kb_json_formatter"
require_relative "formatters/kb_csv_formatter"
require_relative "formatters/kb_markdown_formatter"
require_relative "formatters/kb_report_writer"
require_relative "formatters/kb_annotated_doc_formatter"
require_relative "formatters/kb_annotated_doc_writer"

module SFL
  module Compiler
    module Formatters
      # Output formatters for analysis results
    end
  end
end
