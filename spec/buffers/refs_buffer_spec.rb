# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Refs Buffer", :git, :nvim do
  it "renders, raising no errors" do
    nvim.keys("y")
    expect(nvim.errors).to be_empty
    expect(nvim.filetype).to eq("NeogitRefsView")
  end
end
