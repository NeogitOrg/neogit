# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Log View Buffer", :git, :nvim do
  it "renders, raising no errors" do
    nvim.keys("ll")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitLogView")
  end

  it "can open CommitView" do
    nvim.keys("ll<enter>")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitCommitView")
  end
end
