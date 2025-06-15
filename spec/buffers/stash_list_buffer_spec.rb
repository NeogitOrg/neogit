# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Stash list Buffer", :git, :nvim do
  before do
    create_file("1")
    git.add("1")
    git.commit("test")
    create_file("1", content: "hello world")
    git.lib.stash_save("test")
    nvim.refresh
  end

  it "renders, raising no errors" do
    nvim.keys("Zl")
    expect(nvim.screen[1..2]).to eq(
      [
        " Stashes (1)                                                                    ",
        "stash@{0} On master: test                                          0 seconds ago"
      ]
    )

    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitStashView")
  end

  it "can open CommitView" do
    nvim.keys("Zl<enter>")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitCommitView")
  end
end
