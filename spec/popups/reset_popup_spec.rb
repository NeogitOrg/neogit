# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Reset Popup", :git, :nvim, :popup do
  let(:keymap) { "X" }

  let(:view) do
    [
      " Reset         Reset this                                                       ",
      " f file        m mixed    (HEAD and index)                                      ",
      " b branch      s soft     (HEAD only)                                           ",
      "               h hard     (HEAD, index and files)                               ",
      "               k keep     (HEAD and index, keeping uncommitted)                 ",
      "               i index    (only)                                                ",
      "               w worktree (only)                                                "
    ]
  end

  %w[f b m s h k i w].each { include_examples "interaction", _1 }

  describe "Actions" do
    before do
      git.add_tag("checkpoint") # lightweight tag at initial commit
      File.write("extra.txt", "extra content")
      git.add("extra.txt")
      git.commit("add extra.txt")
      nvim.refresh
    end

    describe "Mixed reset" do
      it "resets HEAD and index to the target commit" do
        target = git.revparse("checkpoint")
        nvim.keys("m")
        nvim.keys("check<cr>")
        await { expect(git.revparse("HEAD")).to eq(target) }
      end
    end

    describe "Soft reset" do
      it "resets HEAD but preserves staged changes" do
        target = git.revparse("checkpoint")
        nvim.keys("s")
        nvim.keys("check<cr>")
        await do
          expect(git.revparse("HEAD")).to eq(target)
          expect(git.status.added.keys).to include("extra.txt")
        end
      end
    end

    describe "Hard reset" do
      it "resets HEAD, index, and working tree" do
        target = git.revparse("checkpoint")
        nvim.keys("h")
        nvim.keys("check<cr>")
        await do
          expect(git.revparse("HEAD")).to eq(target)
          expect(File.exist?("extra.txt")).to be false
        end
      end
    end
  end
end
