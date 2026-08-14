# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Pull Popup", :git, :nvim, :popup do
  let(:keymap) { "p" }
  let(:view) do
    [
      " Variables                                                                      ",
      " r branch.master.rebase [true|false|pull.rebase:false]                          ",
      "                                                                                ",
      " Arguments                                                                      ",
      " -f Fast-forward only (--ff-only)                                               ",
      " -r Rebase local commits (--rebase)                                             ",
      " -a Autostash (--autostash)                                                     ",
      " -t Fetch tags (--tags)                                                         ",
      " -F Force (--force)                                                             ",
      "                                                                                ",
      " Pull into master from           Configure                                      ",
      " p pushRemote, setting that      C Set variables...                             ",
      " u @{upstream}, creating it                                                     ",
      " e elsewhere                                                                    "
    ]
  end

  %w[r -f -r -a -t -F p u e C].each { include_examples "interaction", _1 }

  describe "Actions" do
    describe "Pull from elsewhere", :with_remote_origin do
      before do
        git.push("origin", "master")
        File.write("remote_file.txt", "from remote")
        git.add("remote_file.txt")
        git.commit("remote commit")
        git.push("origin", "master")
        `git reset --hard HEAD^`
        nvim.refresh
      end

      it "pulls commits from a remote branch" do
        nvim.keys("e")
        nvim.keys("origin/master<cr>")
        await do
          expect(git.log(3).entries.map(&:message)).to include("remote commit")
        end
      end
    end
  end
end
