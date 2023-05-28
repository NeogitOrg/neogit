local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.fetch.actions")

local M = {}

function M.create()
  local p = popup
    .builder()
    :name("NeogitFetchPopup")
    :switch("p", "prune", "Prune deleted branches")
    :switch("t", "tags", "Fetch all tags")
    :group_heading("Fetch from")
    :action("p", "pushRemote", actions.fetch_from_pushremote)
    :action("u", "upstream", actions.fetch_from_upstream)
    :action("a", "all remotes", actions.fetch_from_all_remotes)
    :action("e", "elsewhere", actions.fetch_from_elsewhere)
    :new_action_group("Fetch")
    :action("o", "another branch")
    :action("r", "explicit refspec")
    :action("m", "submodules")
    :new_action_group("Configure")
    :action("C", "Set variables...", actions.set_variables)
    :build()

  p:show()

  return p
end

return M
