# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Refs Buffer", :git, :nvim do
  it "renders, raising no errors" do
    input("lr")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitReflogView")
  end

  it "can open CommitView" do
    input("lr<enter>")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitCommitView")
  end
end
