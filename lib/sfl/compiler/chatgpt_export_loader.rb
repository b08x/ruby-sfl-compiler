# frozen_string_literal: true

require "json"

module SFL
  module Compiler
    # Normalizes a ChatGPT export (conversations.json) into sfl-compiler's
    # native turn schema ({name:, is_user:, send_date:, mes:} per turn).
    #
    # ChatGPT's export stores each conversation as a tree (`mapping`:
    # node id => {message, parent, children}) to support branching/regen,
    # not a flat list — the active thread is the path from whichever leaf
    # has no children back to the root, reversed into chronological order.
    # A conversation with multiple leaves (the user regenerated a reply,
    # or edited an earlier message) has more than one possible thread;
    # this loader takes the first leaf found, same as ConvoWorkbench's
    # deleted builder.ts did — picking "the" canonical thread among
    # several isn't a decision a generic loader should make silently
    # beyond matching prior behavior.
    #
    # One export bundles many conversations; #load returns one entry per
    # conversation (see ClaudeExportLoader's docstring for why flattening
    # would be wrong).
    class ChatGPTExportLoader
      Conversation = Struct.new(:id, :title, :turns, keyword_init: true)

      def initialize(conversations_path)
        @conversations_path = conversations_path.to_s
      end

      # @return [Array<Conversation>]
      def self.load(conversations_path)
        new(conversations_path).to_a
      end

      # @return [Array<Conversation>]
      def to_a
        conversations = JSON.parse(File.read(@conversations_path), symbolize_names: true)

        conversations.filter_map do |convo|
          turns = linear_thread(convo[:mapping]).filter_map { |node| turn_for(node) }
          next if turns.empty?

          Conversation.new(id: convo[:id], title: convo[:title], turns:)
        end
      end

      # Walks parent pointers from a leaf node back to the root, then
      # reverses into chronological order. Returns raw mapping nodes
      # (Hash), not turns — #turn_for does the role/text extraction.
      private def linear_thread(mapping)
        return [] unless mapping

        leaf = mapping.values.find { |n| Array(n[:children]).empty? }
        return [] unless leaf

        thread = []
        current = leaf
        while current
          thread << current if real_message?(current)
          current = parent_of(current, mapping)
        end
        thread.reverse
      end

      private def real_message?(node) = node[:message] && node.dig(:message, :author, :role) != "system"

      private def parent_of(node, mapping) = node[:parent] ? mapping[node[:parent].to_sym] : nil

      private def turn_for(node)
        message = node[:message]
        parts = Array(message.dig(:content, :parts)).join("\n")
        return nil if parts.strip.empty?

        is_user = message.dig(:author, :role) == "user"
        { name: is_user ? "User" : "ChatGPT", is_user:, mes: parts, send_date: send_date_for(message) }
      end

      private def send_date_for(message)
        create_time = message[:create_time]
        create_time ? Time.at(create_time).iso8601 : nil
      end
    end
  end
end
