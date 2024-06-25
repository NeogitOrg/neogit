# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Git Command History Buffer", :git, :nvim do
  it "renders, raising no errors" do
    nvim.keys("$")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitGitCommandHistory")
  end
end
