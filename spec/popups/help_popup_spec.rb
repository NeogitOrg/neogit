# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Help Popup", :git, :nvim, :popup do # rubocop:disable RSpec/EmptyExampleGroup
  before { nvim.keys("?") }

  let(:view) do
    [
      " Commands                            Applying changes       Essential commands  ",
      " $ History          M Remote         <c-s> Stage all        <c-r> Refresh       ",
      " A Cherry Pick      m Merge          K Untrack              <cr> Go to file     ",
      " b Branch           P Push           s Stage                <tab> Toggle        ",
      " B Bisect           p Pull           S Stage-Unstaged                           ",
      " c Commit           r Rebase         u Unstage                                  ",
      " d Diff             t Tag            U Unstage-Staged                           ",
      " f Fetch            v Revert         x Discard                                  ",
      " i Ignore           w Worktree                                                  ",
      " I Init             X Reset                                                     ",
      " l Log              Z Stash                                                     "
    ]
  end

  %w[$ A b B c d f i I l M m P p r t v w X Z].each { include_examples "interaction", _1 }
end
