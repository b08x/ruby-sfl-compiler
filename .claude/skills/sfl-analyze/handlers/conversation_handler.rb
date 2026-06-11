# frozen_string_literal: true

module SFLAnalyze
  # Handles /sfl-analyze conversation subcommand
  class ConversationHandler
    def self.handle(path, options = {})
      # Validate input
      raise ArgumentError, "File not found: #{path}" unless File.exist?(path)
      raise ArgumentError, "File must be JSONL format" unless path.end_with?(".jsonl")

      # Prepare script path
      script_path = File.expand_path(
        "../../../../scripts/sfl_analysis/templates/conversation_analysis_template.rb",
        __FILE__
      )

      # Prepare output directory
      output_dir = options[:output_dir] || "./sfl_output"

      # Build command
      cmd = "ruby #{script_path} #{path} #{output_dir}"

      # Return execution info
      {
        script: script_path,
        command: cmd,
        input: path,
        output_dir: output_dir,
        description: "Conversation analysis: tenor tracking, speaker profiling, correlations"
      }
    end
  end
end
