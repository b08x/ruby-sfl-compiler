# frozen_string_literal: true

require "json"

module SFL
  module Compiler
    # Normalizes a Claude.ai web export (conversations.json, with optional
    # projects.json/memories.json) into sfl-compiler's native turn schema
    # ({name:, is_user:, send_date:, mes:} per turn) — the same shape
    # ConversationAnalyzer.load_jsonl reads from a JSONL file.
    #
    # One export bundles many conversations; sfl-compiler's ingest model is
    # one JSONL file per conversation (ConversationAnalyzer#analyze takes a
    # single jsonl_path and treats every line as one continuous session).
    # #load therefore returns one entry per conversation rather than a
    # single flat turn list — flattening would silently interleave
    # unrelated conversations into one fake session.
    #
    # Shape recovered from ConvoWorkbench's client-side builder.ts (now
    # deleted — see the sfl-compiler Multi-Source Corpus Bridging track)
    # before this Ruby port. Tool-use content blocks (Claude's inline
    # "artifacts") are intentionally not extracted here — this loader's
    # job is text-for-SFL-annotation, not full-fidelity artifact capture.
    class ClaudeExportLoader
      Conversation = Struct.new(:id, :title, :turns, keyword_init: true)

      def initialize(conversations_path, projects_path: nil, memories_path: nil)
        @conversations_path = conversations_path.to_s
        @projects_path = projects_path&.to_s
        @memories_path = memories_path&.to_s
      end

      # @return [Array<Conversation>]
      def self.load(conversations_path, **)
        new(conversations_path, **).to_a
      end

      # @return [Array<Conversation>]
      def to_a
        conversations = JSON.parse(File.read(@conversations_path), symbolize_names: true)

        conversations.filter_map do |convo|
          turns = Array(convo[:chat_messages]).filter_map { |msg| turn_for(msg) }
          next if turns.empty?

          Conversation.new(id: convo[:uuid], title: convo[:name], turns:)
        end
      end

      # Memories don't carry role/turn structure — they're standing facts,
      # not dialogue. Returned separately rather than forced into the turn
      # schema; how (or whether) to compile them is left to the caller.
      # @return [Array<Hash>]
      def memories
        return [] unless @memories_path && File.exist?(@memories_path)

        JSON.parse(File.read(@memories_path), symbolize_names: true)
      end

      private def turn_for(msg)
        text = message_text(msg)
        return nil if text.nil? || text.strip.empty?

        is_human = msg[:sender] == "human"
        {
          name: is_human ? "Human" : "Assistant",
          is_user: is_human,
          send_date: msg[:created_at],
          mes: text,
        }
      end

      # Claude messages carry both a flat `.text` and, when the model used
      # tools/artifacts, a richer `.content` block array — prefer the text
      # blocks from `.content` when present (matches builder.ts's own
      # precedence), since `.text` can be stale/empty on tool-use turns.
      private def message_text(msg)
        blocks = Array(msg[:content])
        text_blocks = blocks.select { |b| b[:type] == "text" }.map { |b| b[:text] }
        return text_blocks.join("\n\n") unless text_blocks.empty?

        msg[:text]
      end
    end
  end
end
