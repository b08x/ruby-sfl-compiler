# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::Database do
  describe ".connect" do
    it "selects the fiber-safe timed_queue pool" do
      fake_db = instance_double(Sequel::Database, extension: nil)
      allow(Sequel).to receive(:connect).and_return(fake_db)

      described_class.connect("postgres:///whatever")

      expect(Sequel).to have_received(:connect).with("postgres:///whatever", pool_class: :timed_queue)
    end

    # Regression coverage for a real bug: Falcon runs concurrent requests
    # as Async fibers on one thread. Without both pool_class: :timed_queue
    # AND the fiber_concurrency extension, Sequel hands two sibling fibers
    # the SAME pg connection (its re-entrant-hold fast path keys on
    # Sequel.current, which defaults to Thread.current) and their queries
    # interleave on one socket — surfacing as garbled NoMethodErrors deep
    # in the pg adapter. Asserted directly since #connect's own logic
    # can't be observed any other way without a real Postgres + Async
    # reactor.
    it "loads the fiber_concurrency extension so Sequel.current keys on Fiber.current" do
      expect(Sequel.current).to eq(Fiber.current)
    end
  end
end
