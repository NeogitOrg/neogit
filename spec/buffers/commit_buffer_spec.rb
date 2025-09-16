# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Commit Buffer", :git, :nvim do
  before do
    nvim.keys("ll<enter>")
  end

  it "can close the view with <esc>" do
    nvim.keys("<esc>")
    expect(nvim.filetype).to eq("NeogitLogView")
  end

  it "can close the view with q" do
    nvim.keys("q")
    expect(nvim.filetype).to eq("NeogitLogView")
  end

  it "can yank OID" do
    nvim.keys("Y")
    expect(nvim.screen.last.strip).to match(/\A[a-f0-9]{40}\z/)
  end

  it "can open the bisect popup" do
    nvim.keys("B")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the branch popup" do
    nvim.keys("b")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the cherry pick popup" do
    nvim.keys("A")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the commit popup" do
    nvim.keys("c")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the diff popup" do
    nvim.keys("d")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the pull popup" do
    nvim.keys("p")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the fetch popup" do
    nvim.keys("f")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the ignore popup" do
    nvim.keys("i")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the log popup" do
    nvim.keys("l")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the remote popup" do
    nvim.keys("M")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the merge popup" do
    nvim.keys("m")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the push popup" do
    nvim.keys("P")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the rebase popup" do
    nvim.keys("r")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the tag popup" do
    nvim.keys("t")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the revert popup" do
    nvim.keys("v")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the worktree popup" do
    nvim.keys("w")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the reset popup" do
    nvim.keys("X")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "can open the stash popup" do
    nvim.keys("Z")
    expect(nvim.filetype).to eq("NeogitPopup")
  end
end
