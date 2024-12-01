# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Remote Popup", :git, :nvim, :popup do
  before { nvim.keys("M") }

  let(:view) do
    [
      " Variables                                                                      ",
      " u remote.origin.url unset                                                      ",
      " U remote.origin.fetch unset                                                    ",
      " s remote.origin.pushurl unset                                                  ",
      " S remote.origin.push unset                                                     ",
      " O remote.origin.tagOpt [--no-tags|--tags]                                      ",
      "                                                                                ",
      " Arguments                                                                      ",
      " -f Fetch after add (-f)                                                        ",
      "                                                                                ",
      " Actions                                                                        ",
      " a Add         C Configure...                                                   ",
      " r Rename      p Prune stale branches                                           ",
      " x Remove      P Prune stale refspecs                                           ",
      "               b Update default branch                                          ",
      "               z Unshallow remote                                               "
    ]
  end

  %w[u U s S O a d x C p P b z].each { include_examples "interaction", _1 }
  %w[-f].each { include_examples "argument", _1 }

  describe "add" do
    context "with 'origin 'unset" do
      it "allow user to add remote" do
        nvim.keys("a")
        nvim.keys("origin<cr>")
        nvim.keys("git@github.com:NeogitOrg/neogit.git<cr>")
        expect(git.remote.name).to eq("origin")
        expect(git.remote.url).to eq("git@github.com:NeogitOrg/neogit.git")
      end
    end

    context "with 'origin' set" do
      before do
        git.config("remote.origin.url", "git@github.com:NeogitOrg/neogit.git")
      end

      it "auto-populates host/remote" do
        nvim.keys("a")
        nvim.keys("fork<cr>")
        expect(nvim.screen.last).to start_with("URL for fork: git@github.com:fork/neogit.git")
      end
    end
  end

  describe "remove" do
    context "with no remotes configured" do
      it "notifies user" do
        nvim.keys("x")
        expect(nvim.screen.last).to start_with("No remotes found")
      end
    end

    context "with a remote configured" do
      before do
        git.config("remote.origin.url", "git@github.com:NeogitOrg/neogit.git")
      end

      it "can remove a remote" do
        nvim.keys("x")
        nvim.keys("origin<cr>")
        expect(nvim.screen.last).to start_with("Removed remote 'origin'")
        expect(git.remotes).to be_empty
      end
    end
  end

  describe "rename" do
    context "with no remotes configured" do
      it "notifies user" do
        nvim.keys("r")
        expect(nvim.screen.last).to start_with("No remotes found")
      end
    end

    context "with a remote configured" do
      before do
        git.config("remote.origin.url", "git@github.com:NeogitOrg/neogit.git")
      end

      it "can rename a remote" do
        nvim.keys("r")
        nvim.keys("origin<cr>")
        nvim.keys("fork<cr>")
        expect(nvim.screen.last).to start_with("Renamed 'origin' -> 'fork'")
        expect(git.remotes.first.name).to eq("fork")
      end
    end
  end

  describe "configure" do
    context "with no remotes configured" do
      it "notifies user" do
        nvim.keys("C")
        expect(nvim.screen.last).to start_with("No remotes found")
      end
    end

    context "with a remote configured" do
      before do
        git.config("remote.origin.url", "git@github.com:NeogitOrg/neogit.git")
      end

      it "can launch remote config popup" do
        nvim.keys("C")
        nvim.keys("origin<cr>")
        expect(nvim.screen[14..19]).to eq(
          [" Configure remote                                                               ",
           " u remote.origin.url git@github.com:NeogitOrg/neogit.git                        ",
           " U remote.origin.fetch unset                                                    ",
           " s remote.origin.pushurl unset                                                  ",
           " S remote.origin.push unset                                                     ",
           " O remote.origin.tagOpt [--no-tags|--tags]                                      "]
        )
      end
    end
  end

  describe "prune_branches" do
    context "with no remotes configured" do
      it "notifies user" do
        nvim.keys("p")
        expect(nvim.screen.last).to start_with("No remotes found")
      end
    end

    context "with a remote configured" do
      before do
        git.config("remote.origin.url", "git@github.com:NeogitOrg/neogit.git")
      end

      it "can launch remote config popup" do
        nvim.keys("p")
        nvim.keys("origin<cr>")
        await do
          expect(nvim.screen.last).to start_with("Pruned remote origin")
        end
      end
    end
  end
end
