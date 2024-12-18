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
      " B Bisect           p Pull           S Stage unstaged                           ",
      " c Commit           Q Command        u Unstage                                  ",
      " d Diff             r Rebase         U Unstage all                              ",
      " f Fetch            t Tag            x Discard                                  ",
      " I Init             v Revert                                                    ",
      " i Ignore           w Worktree                                                  ",
      " l Log              X Reset                                                     ",
      "                    Z Stash                                                     "
    ]
  end

  %w[$ A b B c d f i I l M m P p r t v w X Z].each { include_examples "interaction", _1 }
end
