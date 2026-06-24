# frozen_string_literal: true

require "spec_helper"

RSpec.describe SFL::Compiler::StopFlag do
  it "starts unstopped" do
    expect(described_class.new.stopped?).to be(false)
  end

  it "reports stopped after #stop! is called" do
    flag = described_class.new
    flag.stop!
    expect(flag.stopped?).to be(true)
  end
end
