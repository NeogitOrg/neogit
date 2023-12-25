local actions = require("neogit.popups.worktree.actions")
local popup = require("neogit.lib.popup")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitWorktreePopup")
    :group_heading("Worktree")
    :action("w", "Checkout", actions.checkout_worktree)
    :action("W", "Create", actions.create_worktree)
    :new_action_group("Do")
    :action("g", "Goto", actions.visit)
    :action("m", "Move", actions.move)
    :action("D", "Delete", actions.delete)
    :build()

  p:show()

  return p
end

return M
