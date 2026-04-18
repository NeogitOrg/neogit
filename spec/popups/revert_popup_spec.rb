# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Revert Popup", :git, :nvim, :popup do
  let(:keymap) { "v" }

  let(:view) do
    [
      " Arguments                                                                      ",
      " =m Replay merge relative to parent (--mainline=)                               ",
      " -e Edit commit messages (--edit)                                               ",
      " -E Don't edit commit messages (--no-edit)                                      ",
      " -s Add Signed-off-by lines (--signoff)                                         ",
      " =s Strategy (--strategy=)                                                      ",
      " -S Sign using gpg (--gpg-sign=)                                                ",
      "                                                                                ",
      " Revert                                                                         ",
      " v Commit(s)                                                                    ",
      " V Changes                                                                      "
    ]
  end

  %w[v V].each { include_examples "interaction", _1 }
  %w[=m -e -E -s =s -S].each { include_examples "argument", _1 }

  describe "Actions" do
    describe "Revert Changes" do
      before do
        File.write("new_file.txt", "content to revert")
        git.add("new_file.txt")
        git.commit("add new_file")
        nvim.refresh
      end

      it "reverts a commit's changes without opening an editor" do
        nvim.keys("-E") # --no-edit: skip commit message editor
        nvim.keys("V")  # Revert Changes action
        nvim.keys("master<cr>") # master points to HEAD (add new_file commit)
        expect(File.exist?("new_file.txt")).to be false
      end
    end
  end
end
