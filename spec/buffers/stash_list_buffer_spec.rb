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
    expect(nvim.screen[1]).to eq(" Stashes (1)                                                                    ")
    expect(nvim.screen[2]).to match(/\Astash@\{0\} On (main|master): test\s+\d+ seconds? ago\s*\z/)

    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitStashView")
  end

  it "can open CommitView" do
    nvim.keys("Zl<enter>")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitCommitView")
  end
end
