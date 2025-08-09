# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Commit Select Buffer", :git, :nvim do
  it "renders, raising no errors" do
    nvim.keys("AA")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitCommitSelectView")
  end
end
