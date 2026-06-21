# frozen_string_literal: true

require "gum"

module SFL
  module Compiler
    module TUI
      module Wizards
        # Small Gum-prompt helpers shared by the per-subcommand wizards:
        # turning a blank string into nil, and parsing optional numerics.
        # Gum.* returns nil on Esc/Ctrl+C — every wizard treats that as
        # "cancel back to the menu".
        module Prompts
          module_function def blank_to_nil(value)
            (value.nil? || value.strip.empty?) ? nil : value.strip
          end

          module_function def optional_int(value)
            blank_to_nil(value)&.to_i
          end

          module_function def optional_float(value)
            blank_to_nil(value)&.to_f
          end
        end
      end
    end
  end
end
