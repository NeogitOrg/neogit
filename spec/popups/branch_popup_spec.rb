# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Branch Popup", :git, :nvim do
  describe "Variables" do
    describe "branch.<current>.description" do
      it "can edit branch description"
    end

    describe "branch.<current>.{merge,remote}" do
      it "can set the upstream for current branch"
    end

    describe "branch.<current>.rebase" do
      it "can change rebase setting"
    end

    describe "branch.<current>.pushRemote" do
      it "can change pushRemote for current branch"
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
        nvim.feedkeys("bl")
        nvim.feedkeys("master<cr>")
        expect(git.current_branch).to eq "master"
      end

      it "creates and checks out a new local branch when choosing a remote"
    end

    describe "Checkout recent branch" do
      it "can checkout a local branch"
    end

    describe "Checkout new branch" do
      it "can create and checkout a branch" do
        nvim.input("new-branch")
        nvim.feedkeys("bc")
        nvim.feedkeys("master<cr>")

        expect(git.current_branch).to eq "new-branch"
      end

      it "replaces spaces with dashes in user input" do
        nvim.input("new branch with spaces")
        nvim.feedkeys("bc")
        nvim.feedkeys("master<cr>")

        expect(git.current_branch).to eq "new-branch-with-spaces"
      end

      it "lets you pick a base branch" do
        git.branch("new-base-branch").checkout

        nvim.input("feature-branch")
        nvim.feedkeys("bc")
        nvim.feedkeys("master<cr>")

        expect(git.current_branch).to eq "feature-branch"

        expect(
          git.merge_base("feature-branch", "master").first.sha
        ).to eq(git.revparse("master"))
      end
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
    # Requires Neovim 0.10
  end
end
