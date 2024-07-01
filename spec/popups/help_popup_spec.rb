# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Help Popup", :git, :nvim do
  it "renders, raising no errors" do
    nvim.keys("?")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitPopup")
    expect(nvim.screen[10..]).to eq(
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
        " l Log              Z Stash                                                     ",
        "~                                                                               ",
        "NeogitHelpPopup [RO]                                          1,1            All",
        "                                                                                "
      ]
    )
  end
end
