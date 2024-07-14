# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Reflog Buffer", :git, :nvim do
  it "renders for current, raising no errors" do
    nvim.keys("lr")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitReflogView")
  end

  it "renders for HEAD, raising no errors" do
    nvim.keys("lH")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitReflogView")
  end

  it "renders for Other, raising no errors" do
    nvim.keys("lO<cr>")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitReflogView")
  end

  it "can open CommitView" do
    nvim.keys("lr<enter>")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitCommitView")
  end
end
