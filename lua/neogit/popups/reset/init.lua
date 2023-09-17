local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.reset.actions")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeogitResetPopup")
    :group_heading("Reset")
    :action("m", "mixed    (HEAD and index)", actions.mixed)
    :action("s", "soft     (HEAD only)", actions.soft)
    :action("h", "hard     (HEAD, index and files)", actions.hard)
    :action("k", "keep     (HEAD and index, keeping uncommitted)", actions.keep)
    :action("i", "index    (only)", actions.index)
    :action("w", "worktree (only)")
    :group_heading("")
    :action("f", "a file", actions.a_file)
    :env(env)
    :build()

  p:show()

  return p
end

return M
