# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Stash Popup", :git, :nvim, :popup do
  let(:keymap) { "Z" }

  let(:view) do
    [
      " Arguments                                                                      ",
      " -u Also save untracked files (--include-untracked)                             ",
      " -a Also save untracked and ignored files (--all)                               ",
      "                                                                                ",
      " Stash                Snapshot       Use       Inspect   Transform              ",
      " z both               Z both         p pop     l List    b Branch               ",
      " i index              I index        a apply   v Show    B Branch here          ",
      " w worktree           W worktree     d drop              m Rename               ",
      " x keeping index      r to wip ref                       f Format patch         ",
      " P push                                                                         "
    ]
  end

  %w[z i w x P Z I W r p a d l b B m f].each { include_examples "interaction", _1 }
  %w[-u -a].each { include_examples "argument", _1 }

  describe "Stash both" do
    before do
      File.write("foo", "hello foo")
      File.write("bar", "hello bar")
      File.write("baz", "hello baz")
      git.add("foo")
      git.add("bar")
      git.commit("initial commit")
      File.write("foo", "hello world")
      File.write("bar", "hello world")
      git.add("foo")
    end

    context "with --include-untracked" do
      it "stashes staged, unstaged, and untracked changed" do
        nvim.keys("-u")
        nvim.keys("z")
        expect(git.status.changed).to be_empty
        expect(git.status.untracked).to be_empty
      end
    end

    context "with --all" do
      it "stashes staged, unstaged, untracked, and ignored changes" do
        nvim.keys("-a")
        nvim.keys("z")
        expect(git.status.changed).to be_empty
        expect(git.status.untracked).to be_empty
      end
    end

    it "stashes both staged and unstaged changes" do
      nvim.keys("z")
      expect(git.status.changed).to be_empty
      expect(git.status.untracked).not_to be_empty
    end
  end

  describe "Stash index" do
    before do
      File.write("foo", "hello foo") # Staged
      File.write("bar", "hello bar") # Unstaged
      File.write("baz", "hello baz") # Untracked

      git.add("foo")
      git.add("bar")
      git.commit("initial commit")

      File.write("foo", "hello world")
      File.write("bar", "hello world")

      git.add("foo")
    end

    it "stashes only staged changes" do
      nvim.keys("i")
      expect(git.status.changed.keys).to contain_exactly("bar")
      expect(git.status.untracked).not_to be_empty
    end
  end

  describe "Stash Keeping index" do
    before do
      File.write("foo", "hello foo") # Staged
      File.write("bar", "hello bar") # Unstaged
      File.write("baz", "hello baz") # Untracked

      git.add("foo")
      git.add("bar")
      git.commit("initial commit")

      File.write("foo", "hello world")
      File.write("bar", "hello world")

      git.add("foo")
    end

    it "stashes only unstaged changes" do
      nvim.keys("x")
      expect(git.status.changed.keys).to contain_exactly("foo")
      expect(git.status.untracked).not_to be_empty
    end
  end

  describe "Stash push" do
    before do
      File.write("foo", "hello foo") # Staged
      File.write("bar", "hello bar") # Unstaged
      File.write("baz", "hello baz") # Untracked

      git.add("foo")
      git.add("bar")
      git.commit("initial commit")

      File.write("foo", "hello world")
      File.write("bar", "hello world")

      git.add("foo")
    end

    it "stashes only specified file" do
      expect(git.status.changed.keys).to contain_exactly("foo", "bar")

      nvim.keys("Pfoo<cr>")
      expect(git.status.changed.keys).to contain_exactly("bar")

      nvim.keys("ZPbar<cr>")
      expect(git.status.changed.keys).to be_empty
    end
  end

  describe "Pop stash" do
    before do
      File.write("testfile", "modified by stash")
      `git stash`
      nvim.refresh
    end

    it "restores stashed changes and removes the stash entry" do
      nvim.keys("p")
      nvim.keys("<cr>") # select first stash
      expect(File.read("testfile")).to eq("modified by stash")
      expect(`git stash list`).to be_empty
    end
  end

  describe "Apply stash" do
    before do
      File.write("testfile", "applied content")
      `git stash`
      nvim.refresh
    end

    it "restores stashed changes without removing the stash entry" do
      nvim.keys("a")
      nvim.keys("<cr>") # select first stash
      expect(File.read("testfile")).to eq("applied content")
      expect(`git stash list`).not_to be_empty
    end
  end

  describe "Drop stash" do
    before do
      File.write("testfile", "to be dropped")
      `git stash`
      nvim.refresh
    end

    it "removes the stash entry" do
      nvim.keys("d")
      nvim.keys("<cr>") # select first stash
      expect(`git stash list`).to be_empty
    end
  end

  describe "Rename stash" do
    before do
      File.write("testfile", "original stash content")
      `git stash`
      nvim.refresh
    end

    it "updates the stash message" do
      nvim.input("my-renamed-stash")
      nvim.keys("m")
      nvim.keys("<cr>") # select first stash

      expect(`git stash list`).to include("my-renamed-stash")
    end

    it "does not drop the stash when renaming" do
      nvim.input("renamed-stash")
      nvim.keys("m")
      nvim.keys("<cr>") # select first stash

      expect(`git stash list`).not_to be_empty
    end

    it "preserves the stash content after renaming" do
      nvim.input("content-check")
      nvim.keys("m")
      nvim.keys("<cr>") # select first stash

      `git stash pop`
      expect(File.read("testfile")).to eq("original stash content")
    end

    it "renames stash@{0} correctly when the abbreviate_commit cache is stale" do
      # Seed the memoize cache: abbreviate_commit("stash@{0}") now permanently
      # returns the OID of the original stash (OID_A), even after the stash
      # list changes.  This mimics the state left behind by a previous rename
      # (or any earlier call) with timeout = math.huge.
      nvim.lua("require('neogit.lib.git').rev_parse.abbreviate_commit('stash@{0}')")

      # Push a second stash on top: stash@{0} = OID_B ("second-stash-content"),
      # stash@{1} = OID_A ("original stash content").
      File.write("testfile", "second-stash-content")
      `git stash`
      nvim.refresh

      expect(`git stash list`.lines.count).to eq(2)

      # Rename stash@{0}.  Because abbreviate_commit is memoized forever, it
      # still returns OID_A instead of OID_B.  The rename therefore drops
      # stash@{0} (OID_B / "second-stash-content") and re-stores OID_A under
      # the new name — silently losing "second-stash-content".
      nvim.input("second-stash-renamed")
      nvim.keys("m")
      nvim.keys("<cr>") # select stash@{0}

      stash_list = `git stash list`

      # Both stashes must still exist.
      expect(stash_list.lines.count).to eq(2)

      # stash@{0} must carry the new name.
      expect(stash_list.lines.first).to include("second-stash-renamed")

      # Applying stash@{0} must restore the content of the second stash (OID_B).
      # With the bug, OID_B is silently dropped and OID_A (original content)
      # ends up at stash@{0} instead.
      `git stash pop`
      expect(File.read("testfile")).to eq("second-stash-content")
    end
  end
end
