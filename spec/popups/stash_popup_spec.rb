# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Stash Popup", :git, :nvim, :popup do
  before { nvim.keys("Z") }

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
end
