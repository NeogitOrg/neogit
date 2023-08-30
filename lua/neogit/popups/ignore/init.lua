local actions = require("neogit.popups.stash.actions")
local popup = require("neogit.lib.popup")

local M = {}

function M.create(env)
  -- TODO:
  -- :switch("u", "include-untracked", "Also save untracked files")
  -- :switch("a", "all", "Also save untracked and ignored files")

  local p = popup
    .builder()
    :name("NeogitIgnorePopup")
    :action("t", "shared at top level", actions.shared)
    :action("s", "shared at subdirectory")
    :action("p", "private (.git/info/exclude)", actions.private)
    :action("g", "private for all repositories")
    :build()

  p:show()

  return p
end

return M
