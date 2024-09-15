# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Log Buffer", :git, :nvim do
  it "renders current, raising no errors" do
    input("ll")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitLogView")
    expect(nvim.screen[1].strip).to eq("Commits in master")
  end

  it "renders HEAD, raising no errors" do
    input("lh")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitLogView")
    expect(nvim.screen[1].strip).to eq("Commits in HEAD")
  end

  it "renders related, raising no errors" do
    input("lu")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitLogView")
    expect(nvim.screen[1].strip).to eq("Commits in master")
  end

  it "renders other, raising no errors" do
    input("lo<cr>")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitLogView")
    expect(nvim.screen[1].strip).to eq("Commits in master")
  end

  it "renders local branches, raising no errors" do
    input("lL")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitLogView")
    expect(nvim.screen[1].strip).to eq("Commits in --branches")
  end

  it "renders all branches, raising no errors" do
    input("lb")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitLogView")
    expect(nvim.screen[1].strip).to eq("Commits in --branches --remotes")
  end

  it "renders all references, raising no errors" do
    input("la")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitLogView")
    expect(nvim.screen[1].strip).to eq("Commits in --all")
  end

  it "can open CommitView" do
    input("ll<down><enter>")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitCommitView")
  end
end
