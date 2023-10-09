local actions = require("neogit.popups.ignore.actions")
local popup = require("neogit.lib.popup")

local M = {}

---@class IgnoreEnv
---@field files string[] Abolute paths
function M.create(env)
  local excludesFile = require("neogit.lib.git.config").get_global("core.excludesfile")

  local p = popup
    .builder()
    :name("NeogitIgnorePopup")
    :group_heading("Gitignore")
    :action("t", "shared at toplevel             (.gitignore)", actions.shared_toplevel)
    :action("s", "shared in subdirectory         (path/to/.gitignore)", actions.shared_subdirectory)
    :action("p", "privately for this repository  (.git/info/exclude)", actions.private_local)
    :action_if(
      excludesFile:is_set(),
      "g",
      string.format("privately for all repositories (%s)", excludesFile:read()),
      actions.private_global
    )
    :env(env)
    :build()

  p:show()

  return p
end

return M
