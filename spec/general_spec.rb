# frozen_string_literal: true

RSpec.describe "general things", :git, :nvim do
  popups = %w[
    bisect branch branch_config cherry_pick commit
    diff fetch help ignore log merge pull push rebase
    remote remote_config reset revert stash tag worktree
  ]

  popups.each do |popup|
    it "can invoke #{popup} popup without status buffer", :with_remote_origin do
      nvim.keys("q")
      nvim.lua("require('neogit').open({ '#{popup}' })")
      sleep(0.1) # Allow popup to open

      expect(nvim.filetype).to eq("NeogitPopup")
      expect(nvim.errors).to be_empty
    end
  end
end
