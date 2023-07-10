local actions = require("neogit.popups.revert.actions")
local popup = require("neogit.lib.popup")

local M = {}

function M.create(commits)
  -- TODO: enabled = true needs to check if incompatible switch is toggled in internal state, and not apply.
  --       if you enable 'no edit', and revert, next time you load the popup both will be enabled
  --
  -- :option("s", "strategy", "", "Strategy")
  -- :switch("s", "signoff", "Add Signed-off-by lines")
  -- :option("S", "gpg-sign", "", "Sign using gpg")

  local p = popup
    .builder()
    :name("NeogitRevertPopup")
    :option("m", "mainline", "", "Replay merge relative to parent")
    :switch("e", "edit", "Edit commit messages", { enabled = true, incompatible = { "no-edit" } })
    :switch("E", "no-edit", "Don't edit commit messages", { incompatible = { "edit" } })
    :action("_", "Revert commit", actions.commits) -- TODO: Support multiple commits
    :action("v", "Revert changes")
    :env({ commits = commits or {} })
    :build()

  p:show()

  return p
end

return M
