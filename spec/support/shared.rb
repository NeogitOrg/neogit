# frozen_string_literal: true

RSpec.shared_examples "interaction" do |keys|
  it "raises no errors with '#{keys}'" do
    nvim.keys(keys)
    expect(nvim.errors).to be_empty
  end
end

RSpec.shared_examples "argument" do |keys|
  it "raises no errors with '#{keys}'" do
    nvim.keys(keys)
    expect(nvim.errors).to be_empty
  end
end

RSpec.shared_examples "popup", :popup do
  it "raises no errors" do
    expect(nvim.errors).to be_empty
  end

  it "has correct filetype" do
    expect(nvim.filetype).to eq("NeogitPopup")
  end

  it "renders view properly" do
    screen  = nvim.screen
    indices = view.map { screen.index(_1) }
    range   = (indices.first..indices.last)
    expect(screen[range]).to eq(view)
  end
end
