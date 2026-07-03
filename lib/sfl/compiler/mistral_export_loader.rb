# frozen_string_literal: true

require "json"

module SFL
  module Compiler
    # Normalizes a Mistral Le Chat export into sfl-compiler's native turn
    # schema ({name:, is_user:, send_date:, mes:} per turn).
    #
    # Shape verified 2026-07-03 against a real export (Le Chat has no
    # documented/official export format — this loader is built directly
    # from a sample export file, not a spec, since none exists): unlike
    # Claude/ChatGPT, Le Chat exports one flat JSON array per
    # conversation (chat-<uuid>.json — no bundling file, no tree
    # structure, no separate title field). Each element:
    #   {id:, chatId:, content:, contentChunks:, role:, createdAt:,
    #    canvas:, files:, ...}
    # `content` already carries the flattened text for both roles
    # (contentChunks is redundant with it, present only on assistant
    # turns) — no reconstruction needed, unlike Claude's tool-use blocks.
    #
    # @param path [String] a single chat-<uuid>.json file, or a directory
    #   containing many of them (the export's actual on-disk shape)
    class MistralExportLoader
      Conversation = Struct.new(:id, :title, :turns, keyword_init: true)

      def initialize(path)
        @path = path.to_s
      end

      # @return [Array<Conversation>]
      def self.load(path)
        new(path).to_a
      end

      # @return [Array<Conversation>]
      def to_a
        chat_files.filter_map { |file| conversation_for(file) }
      end

      private def chat_files
        if File.directory?(@path)
          Dir.glob(File.join(@path, "chat-*.json"))
        else
          [@path]
        end
      end

      private def conversation_for(file)
        messages = JSON.parse(File.read(file), symbolize_names: true)
        return nil if messages.empty?

        turns = messages.filter_map { |msg| turn_for(msg) }
        return nil if turns.empty?

        chat_id = messages.first[:chatId] || File.basename(file, ".json").delete_prefix("chat-")
        Conversation.new(id: chat_id, title: nil, turns:)
      end

      private def turn_for(msg)
        text = msg[:content]
        return nil if text.nil? || text.strip.empty?

        is_user = msg[:role] == "user"
        {
          name: is_user ? "User" : "Mistral",
          is_user:,
          send_date: msg[:createdAt],
          mes: text,
        }
      end
    end
  end
end
