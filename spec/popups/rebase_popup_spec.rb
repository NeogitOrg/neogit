# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Rebase Popup", :git, :nvim, :popup do
  let(:keymap) { "r" }

  let(:view) do
    [
      " Arguments                                                                      ",
      " -k Keep empty commits (--keep-empty)                                           ",
      " -r Rebase merges (--rebase-merges=)                                            ",
      " -u Update branches (--update-refs)                                             ",
      " -d Use author date as committer date (--committer-date-is-author-date)         ",
      " -t Use current time as author date (--ignore-date)                             ",
      " -a Autosquash (--autosquash)                                                   ",
      " -A Autostash (--autostash)                                                     ",
      " -i Interactive (--interactive)                                                 ",
      " -h Disable hooks (--no-verify)                                                 ",
      " -S Sign using gpg (--gpg-sign=)                                                ",
      "                                                                                ",
      " Rebase master onto              Rebase                                         ",
      " p pushRemote, setting that      i interactively   m to modify a commit         ",
      " u @{upstream}, creating it      s a subset        w to reword a commit         ",
      " e elsewhere                                       d to remove a commit         ",
      "                                                   f to autosquash              "
    ]
  end

  %w[p u e i s m w d f].each { include_examples "interaction", _1 }
  %w[-k -r -u -d -t -a -A -i -h -S].each { include_examples "argument", _1 }

  describe "Actions" do
    describe "Rebase onto elsewhere" do
      before do
        # Create a diverged history: feature branch made from initial commit,
        # then a new commit added to master.
        git.branch("base-branch").checkout
        git.branch("master").checkout
        File.write("master_work.txt", "master work")
        git.add("master_work.txt")
        git.commit("master work")
        nvim.refresh
      end

      it "rebases the current branch onto a target branch" do
        nvim.keys("e")
        nvim.keys("base<cr>") # fuzzy-match "base-branch"
        # After rebase onto base-branch, the master_work commit is replayed on
        # top of base-branch (which equals the initial commit).
        expect(git.revparse("HEAD^")).to eq(git.revparse("base-branch"))
      end
    end
  end
end
