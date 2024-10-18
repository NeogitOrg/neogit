# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Revert Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("v") }

  let(:view) do
    [
      " Arguments                                                                      ",
      " =m Replay merge relative to parent (--mainline=)                               ",
      " -e Edit commit messages (--edit)                                               ",
      " -E Don't edit commit messages (--no-edit)                                      ",
      "                                                                                ",
      " Revert                                                                         ",
      " v Commit(s)                                                                    ",
      " V Changes                                                                      "
    ]
  end

  %w[v V].each { include_examples "interaction", _1 }
  %w[=m -e -E].each { include_examples "argument", _1 }
end
