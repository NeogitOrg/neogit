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

  it "can open Yank popup" do
    nvim.keys("Y")
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  if ENV["CI"].nil? # Fails in GHA :'(
    it "can yank oid" do
      nvim.keys("YY")
      yank = nvim.cmd("echo @*").first
      expect(yank).to match(/[0-9a-f]{40}/)
    end

    it "can yank author" do
      nvim.keys("Ya")
      yank = nvim.cmd("echo @*").first
      expect(yank).to eq("tester <test@example.com>")
    end

    it "can yank subject" do
      nvim.keys("Ys")
      yank = nvim.cmd("echo @*").first
      expect(yank).to eq("Initial commit")
    end

    it "can yank message" do
      nvim.keys("Ym")
      yank = nvim.cmd("echo @*")
      expect(yank).to contain_exactly("Initial commit\n", "commit message")
    end

    it "can yank body" do
      nvim.keys("Yb")
      yank = nvim.cmd("echo @*").first
      expect(yank).to eq("commit message")
    end

    it "can yank diff" do
      nvim.keys("Yd")
      yank = nvim.cmd("echo @*")
      expect(yank).to contain_exactly("@@ -0,0 +1 @@\n", "+hello, world")
    end

    it "can yank tag" do
      git.add_tag("test-tag", "HEAD")
      nvim.keys("Yt")
      yank = nvim.cmd("echo @*").first
      expect(yank).to eq("test-tag")
    end

    it "can yank tags" do
      git.add_tag("test-tag-a", "HEAD")
      git.add_tag("test-tag-b", "HEAD")
      nvim.keys("Yt")
      yank = nvim.cmd("echo @*").first
      expect(yank).to eq("test-tag-a, test-tag-b")
    end
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

  describe "reversing" do
    it "reverses a hunk into the working tree" do
      nvim.move_to_line("+hello, world")
      nvim.confirm(true)
      nvim.keys("-")
      await { expect(File.read("testfile")).to eq("") }
    end

    it "reverses all changes in a file into the working tree" do
      nvim.move_to_line("new file testfile")
      nvim.confirm(true)
      nvim.keys("-")
      await { expect(File.read("testfile")).to eq("") }
    end

    it "reverses all diffs in the commit when cursor is on metadata" do
      # Cursor starts at the top of the commit view (on metadata, outside any diff)
      nvim.confirm(true)
      nvim.keys("-")
      await { expect(File.read("testfile")).to eq("") }
    end
  end
end
