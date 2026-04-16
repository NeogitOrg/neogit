# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Bisect Popup", :git, :nvim, :popup do
  let(:keymap) { "B" }
  let(:view) do
    [
      " Arguments                                                                      ",
      " -r Don't checkout commits (--no-checkout)                                      ",
      " -p Follow only first parent of a merge (--first-parent)                        ",
      "                                                                                ",
      " Bisect                                                                         ",
      " B Start                                                                        ",
      " S Scripted                                                                     "
    ]
  end

  %w[-r -p].each { include_examples "argument", _1 }
  %w[B S].each { include_examples "interaction", _1 }

  describe "Actions" do
    describe "Start bisect" do
      before do
        git.add_tag("known-good") # tag initial commit as good baseline
        3.times do |i|
          File.write("step#{i}.txt", i.to_s)
          git.add("step#{i}.txt")
          git.commit("step #{i}")
        end
        nvim.refresh
      end

      it "starts a bisect session between good and bad revisions" do
        nvim.keys("B")              # Start action
        nvim.keys("HEAD<cr>")       # bad revision (first fuzzy finder)
        nvim.keys("known-good<cr>") # good revision (second fuzzy finder)
        expect(File.exist?(".git/BISECT_LOG")).to be true
      end
    end
  end
end
