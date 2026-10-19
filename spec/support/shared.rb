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
  before do
    nvim.keys(keymap)
  end

  it "raises no errors" do
    expect(nvim.errors).to be_empty
  end

  it "raises no errors with detached HEAD" do
    nvim.keys("<esc>") # close popup

    # Detach HEAD
    git.commit("dummy commit", allow_empty: true)
    git.checkout("HEAD^")

    sleep(1) # Allow state to propagate
    nvim.keys(keymap) # open popup
    expect(nvim.errors).to be_empty
  end

  it "has correct filetype" do
    await { expect(nvim.filetype).to eq("NeogitPopup") }
  end

  it "renders view properly" do
    await do
      screen  = nvim.screen
      indices = view.map { screen.index(it) }
      expect(indices).to all(be_a(Integer))
      range = (indices.first..indices.last)
      expect(screen[range]).to eq(view)
    end
  end
end
