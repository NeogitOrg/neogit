local actions = require("neogit.popups.ignore.actions")
local popup = require("neogit.lib.popup")

local M = {}

function M.create(env)
  local p = popup
    .builder()
    :name("NeogitIgnorePopup")
    :action("t", "shared at top level", actions.shared)
    :action("s", "shared at subdirectory")
    :action("p", "private (.git/info/exclude)", actions.private)
    :action("g", "private for all repositories")
    :env(env)
    :build()

  p:show()

  return p
end

return M
