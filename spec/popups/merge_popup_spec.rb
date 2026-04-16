# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Merge Popup", :git, :nvim, :popup do
  let(:keymap) { "m" }
  let(:view) do
    [
      " Arguments                                                                      ",
      " -f Fast-forward only (--ff-only)                                               ",
      " -n No fast-forward (--no-ff)                                                   ",
      " -s Strategy (--strategy=)                                                      ",
      " -X Strategy Option (--strategy-option=)                                        ",
      " -b Ignore changes in amount of whitespace (-Xignore-space-change)              ",
      " -w Ignore whitespace when comparing lines (-Xignore-all-space)                 ",
      " -A Diff algorithm (-Xdiff-algorithm=)                                          ",
      " -S Sign using gpg (--gpg-sign=)                                                ",
      "                                                                                ",
      " Actions                                                                        ",
      " m Merge                       p Preview merge                                  ",
      " e Merge and edit message                                                       ",
      " n Merge but don't commit      s Squash merge                                   ",
      " a Absorb                      i Dissolve                                       "
    ]
  end

  %w[m e n s a p i].each { include_examples "interaction", _1 }
  %w[-f -n -s -X -b -w -A -S].each { include_examples "argument", _1 }

  describe "Actions" do
    describe "Merge" do
      before do
        git.branch("feature").checkout
        File.write("feature.txt", "feature content")
        git.add("feature.txt")
        git.commit("add feature.txt")
        git.branch("master").checkout
        nvim.refresh
      end

      it "merges a branch into the current branch" do
        nvim.keys("m")
        nvim.keys("feat<cr>")
        expect(File.exist?("feature.txt")).to be true
        expect(git.log(5).entries.map(&:message)).to include("add feature.txt")
      end
    end

    describe "Squash merge" do
      before do
        git.branch("feature").checkout
        File.write("squashed.txt", "squashed content")
        git.add("squashed.txt")
        git.commit("squashed commit")
        git.branch("master").checkout
        nvim.refresh
      end

      it "merges a branch as a single squashed commit" do
        nvim.keys("s")
        nvim.keys("feat<cr>")
        expect(File.exist?("squashed.txt")).to be true
      end
    end
  end
end
