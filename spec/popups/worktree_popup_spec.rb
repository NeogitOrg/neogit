# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Worktree Popup", :git, :nvim do
  let(:dir) { "worktree_test_#{SecureRandom.hex(4)}" }

  after do # Cleanup worktree dirs
    Dir[File.join(Dir.tmpdir, "worktree_test_*")].each do |tmpdir|
      FileUtils.rm_rf(tmpdir)
    end
  end

  describe "Actions" do
    describe "Checkout" do
      before do
        git.branch("worktree-test").checkout
        git.branch("master").checkout
      end

      it "creates a worktree for an existing branch and checks it out", :aggregate_failures do
        nvim.keys("ww")             # Open popup/action
        nvim.keys("wor<cr>")        # Select "worktree-test" branch
        nvim.keys("<cr>#{dir}<cr>") # go up level, new folder name

        expect(git.worktrees.map(&:dir).last).to match(%r{/#{dir}$})
        expect(nvim.cmd("pwd").first).to match(%r{/#{dir}$})
      end
    end

    describe "Create" do
      before do
        git.branch("worktree-test").checkout
        git.branch("master").checkout
      end

      it "creates a worktree for a new branch and checks it out", :aggregate_failures do
        nvim.input("create-worktree-test") # Branch name

        nvim.keys("wW")             # Open popup/action
        nvim.keys("<cr>#{dir}<cr>") # go up level, new folder name
        nvim.keys("mas<cr>")        # Set base branch to 'master'

        expect(git.worktrees.map(&:dir).last).to match(%r{/#{dir}$})
        expect(nvim.cmd("pwd").first).to match(%r{/#{dir}$})
      end
    end

    describe "Goto" do
    end

    describe "Move" do
    end

    describe "Delete" do
    end
  end
end
