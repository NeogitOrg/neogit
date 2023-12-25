local actions = require("neogit.popups.worktree.actions")
local popup = require("neogit.lib.popup")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitWorktreePopup")
    :group_heading("Checkout")
    :action("w", "worktree", actions.checkout_worktree)
    :new_action_group("Create")
    :action("c", "branch and worktree", actions.create_worktree)
    :new_action_group("Commands")
    :action("g", "Goto", actions.visit)
    :action("m", "Move", actions.move)
    :action("D", "Delete", actions.delete)
    :build()

  p:show()

  return p
end

return M
