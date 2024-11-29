# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Worktree Popup", :git, :nvim, :popup do
  before { nvim.keys("w") }

  let(:view) do
    [
      " Worktree        Do                                                             ",
      " w Checkout      g Goto                                                         ",
      " W Create        m Move                                                         ",
      "                 D Delete                                                       "
    ]
  end

  let(:dir) { "worktree_test_#{SecureRandom.hex(4)}" }

  after do # Cleanup worktree dirs
    Dir[File.join(Dir.tmpdir, "worktree_test_*")].each do |tmpdir|
      FileUtils.rm_rf(tmpdir)
    end
  end

  %w[w W g m D].each { include_examples "interaction", _1 }

  describe "Actions" do
    describe "Checkout" do
      before do
        git.branch("worktree-test").checkout
        git.branch("master").checkout
      end

      it "creates a worktree for an existing branch and checks it out", :aggregate_failures do
        nvim.keys("w")           # Action
        nvim.keys("wor<cr>")     # Select "worktree-test" branch
        nvim.keys("#{dir}/<cr>") # go up level, new folder name

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
        nvim.keys("W")                        # Action
        nvim.keys("#{dir}/<cr>")              # new folder name
        nvim.keys("mas<cr>")                  # Set base branch to 'master'
        nvim.keys("create-worktree-test<cr>") # branch name

        expect(git.worktrees.map(&:dir).last).to match(%r{/#{dir}$})
        expect(nvim.cmd("pwd").first).to match(%r{/#{dir}$})
      end
    end

    # describe "Goto" do
    # end

    # describe "Move" do
    # end

    # describe "Delete" do
    # end
  end
end
