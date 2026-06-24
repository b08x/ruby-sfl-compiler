# frozen_string_literal: true

module SFL
  module Compiler
    # Cooperative stop signal for the "clean quit" feature: a SIGINT trap
    # (installed by CLI) calls #stop!, and ConversationAnalyzer/
    # DocumentationAnalyzer poll #stopped? once per turn/section, finishing
    # whatever turn is already in flight before breaking out. Plain
    # boolean read/write needs no Mutex — there's exactly one writer (the
    # trap) and one reader (the turn loop), never concurrently.
    class StopFlag
      def initialize
        @stopped = false
      end

      def stop!
        @stopped = true
      end

      def stopped?
        @stopped
      end
    end
  end
end
