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
    :action_if(diffview, "u", "unstaged", actions.unstaged)
    :action_if(diffview, "s", "staged", actions.staged)
    :action_if(diffview, "w", "worktree", actions.worktree)
    :new_action_group("Show")
    :action("c", "Commit")
    :action_if(diffview, "t", "Stash", actions.stash)
    :env(env)
    :build()

  p:show()

  return p
end

return M
