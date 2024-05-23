local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.reset.actions")
local branch_actions = require("neogit.popups.branch.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeogitResetPopup")
    :group_heading("Reset")
    :action("f", "file", actions.a_file)
    :action("b", "branch", branch_actions.reset_branch)
    :new_action_group("Reset this")
    :action("m", "mixed    (HEAD and index)", actions.mixed)
    :action("s", "soft     (HEAD only)", actions.soft)
    :action("h", "hard     (HEAD, index and files)", actions.hard)
    :action("k", "keep     (HEAD and index, keeping uncommitted)", actions.keep)
    :action("i", "index    (only)", actions.index)
    :action("w", "worktree (only)", actions.worktree)
    :env(env)
    :build()

  p:show()

  return p
end

return M
