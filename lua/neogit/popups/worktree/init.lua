local actions = require("neogit.popups.worktree.actions")
local popup = require("neogit.lib.popup")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeogitWorktreePopup")
    :group_heading("Checkout")
    :action("w", "worktree", actions.worktree)
    :new_action_group("Create")
    :action("c", "branch and worktree")
    :new_action_group("Commands")
    :action("g", "Goto", actions.visit)
    :action("m", "Move", actions.move)
    :action("D", "Delete", actions.delete)
    :env(env)
    :build()

  p:show()

  return p
end

return M
