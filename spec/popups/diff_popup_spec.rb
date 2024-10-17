# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Diff Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("d") }

  let(:view) do
    [
      " Diff                      Show                                                 ",
      " d this       u unstaged   c Commit                                             ",
      " r range      s staged     t Stash                                              ",
      " p paths      w worktree                                                        "
    ]
  end

  %w[d r p u s w c t].each { include_examples "interaction", _1 }
end
