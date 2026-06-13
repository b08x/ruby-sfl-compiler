# frozen_string_literal: true

module SFL
  module Compiler
    module Formatters
      # Renders a Types::NarrativeReport as markdown. Deterministic
      # assembly: the LLM wrote the prose, this class owns the skeleton.
      class NarrativeFormatter < BaseFormatter
        SECTIONS = [
          ["Overview", :overview],
          ["Cast & Roles", :cast_and_roles],
          ["Interpersonal Dynamics", :interpersonal_dynamics],
          ["Conversational Arc", :conversational_arc],
          ["Data Quality", :data_quality],
          ["Takeaways", :takeaways]
        ].freeze

        def render
          body = SECTIONS.map do |title, key|
            "## #{title}\n\n#{result.public_send(key)}\n"
          end.join("\n")

          <<~MARKDOWN
            # Narrative Report: #{result.source}

            *Generated #{result.generated_at.iso8601} by sfl-compiler narrative generation.*

            #{body}
          MARKDOWN
        end
      end
    end
  end
end
