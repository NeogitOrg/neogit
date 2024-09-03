# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Branch Popup", :git, :nvim do
  describe "Variables" do
    describe "branch.<current>.description" do
      it "can edit branch description" do
        nvim.keys("bd")
        nvim.keys("describe the branch<esc>")
        nvim.keys(":wq<cr>")

        expect(git.config("branch.master.description")).to eq("describe the branch\n")
      end
    end

    describe "branch.<current>.{merge,remote}" do
      it "can set the upstream for current branch" do
        expect_git_failure { git.config("branch.#{git.branch.name}.remote") }
        expect_git_failure { git.config("branch.#{git.branch.name}.merge") }

        nvim.keys("bumaster<cr>")
        expect(git.config("branch.#{git.branch.name}.remote")).to eq(".")
        expect(git.config("branch.#{git.branch.name}.merge")).to eq("refs/heads/master")
      end
    end

    describe "branch.<current>.rebase" do
      before { git.config("pull.rebase", "false") }

      it "can change rebase setting" do
        expect_git_failure { git.config("branch.#{git.branch.name}.rebase") }
        expect(git.config("pull.rebase")).to eq("false")
        nvim.keys("bR")
        expect(git.config("branch.#{git.branch.name}.rebase")).to eq("true")
        nvim.keys("R")
        expect(git.config("branch.#{git.branch.name}.rebase")).to eq("false")
        nvim.keys("R")
        expect_git_failure { git.config("branch.#{git.branch.name}.rebase") }
      end
    end

    describe "branch.<current>.pushRemote", :with_remote_origin do
      it "can change pushRemote for current branch" do
        expect_git_failure { git.config("branch.master.pushRemote") }
        nvim.keys("bp")
        expect(git.config("branch.master.pushRemote")).to eq("origin")
      end
    end
  end

  describe "Actions" do
    describe "Checkout branch/revision" do
      it "can checkout a local branch"
      it "can checkout a remote branch"
      it "can checkout a tag"
      it "can checkout HEAD"
      it "can checkout a commit"
    end

    describe "Checkout local branch" do
      before { git.branch("new-local-branch").checkout }

      it "can checkout a local branch" do
        nvim.keys("bl")
        nvim.keys("master<cr>")

        expect(git.current_branch).to eq "master"
      end

      it "creates and checks out a new local branch when choosing a remote"

      it "creates and checks out a new local branch when name doesn't match existing local branch", skip: "requires FZF sorter" do # rubocop:disable Layout/LineLength
        nvim.keys("bl")
        nvim.keys("this branch doesnt exist<cr>")
        nvim.keys("master<cr>")
        expect(git.current_branch).to eq "this-branch-doesnt-exist"
      end
    end

    describe "Checkout recent branch" do
      it "can checkout a local branch"
    end

    describe "Checkout new branch" do
      it "can create and checkout a branch" do
        nvim.input("new-branch")
        nvim.keys("bc")
        nvim.keys("master<cr>")

        expect(git.current_branch).to eq "new-branch"
      end

      it "replaces spaces with dashes in user input" do
        nvim.input("new branch with spaces")
        nvim.keys("bc")
        nvim.keys("master<cr>")

        expect(git.current_branch).to eq "new-branch-with-spaces"
      end

      it "lets you pick a base branch" do
        git.branch("new-base-branch").checkout

        nvim.input("feature-branch")
        nvim.keys("bc")
        nvim.keys("master<cr>")

        expect(git.current_branch).to eq "feature-branch"

        expect(
          git.merge_base("feature-branch", "master").first.sha
        ).to eq(git.revparse("master"))
      end
    end

    describe "Checkout new spin-off" do
      it "can create and checkout a spin-off branch"
    end

    describe "Checkout new worktree" do
      it "can create and checkout a worktree"
    end

    describe "Create new branch" do
      it "can create a new branch"
    end

    describe "Create new spin-off" do
      it "can create a new spin-off"

      context "when there are uncommitted changes" do
        it "checks out the spun-off branch"
      end
    end

    describe "Create new worktree" do
      it "can create a new worktree"
    end

    describe "Configure" do
      it "Launches the configuration popup"
    end

    describe "Rename" do
      it "can rename a branch"
    end

    describe "reset" do
      it "can reset a branch"
    end

    describe "delete" do
      it "can delete a branch"
    end

    describe "pull request" do
      it "can open a pull-request"
    end
  end
end
