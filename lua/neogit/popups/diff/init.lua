local M = {}

local config = require("neogit.config")
local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.diff.actions")

function M.create(env)
  local diffview = config.check_integration("diffview")

  local p = popup
    .builder()
    :name("NeogitDiffPopup")
    :group_heading("Diff")
    :action_if(diffview, "d", "this", actions.this)
    :action("r", "range")
    :action("p", "paths")
    :new_action_group()
    :action("u", "unstaged")
    :action("s", "staged")
    :action_if(diffview, "w", "worktree", actions.worktree)
    :new_action_group("Show")
    :action("c", "Commit")
    :action("t", "Stash")
    :env(env)
    :build()

  p:show()

  return p
end

return M
