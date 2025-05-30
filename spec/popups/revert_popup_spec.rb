# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Revert Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
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
end
