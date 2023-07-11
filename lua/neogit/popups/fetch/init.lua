local actions = require("neogit.popups.fetch.actions")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local M = {}

function M.create()
  local upstream = actions.upstream()

  local p = popup
    .builder()
    :name("NeogitFetchPopup")
    :switch("p", "prune", "Prune deleted branches")
    :switch("t", "tags", "Fetch all tags")
    :group_heading("Fetch from")
    :action("p", git.branch.pushRemote_label(), actions.fetch_pushremote)
    :action_if(upstream, "u", upstream, actions.fetch_upstream)
    :action("e", "elsewhere", actions.fetch_elsewhere)
    :action("a", "all remotes", actions.fetch_all_remotes)
    :new_action_group("Fetch")
    :action("o", "another branch", actions.fetch_another_branch)
    :action("r", "explicit refspec", actions.fetch_refspec)
    :action("m", "submodules", actions.fetch_submodules)
    :new_action_group("Configure")
    :action("C", "Set variables...", actions.set_variables)
    :env({ highlight = { git.branch.pushRemote() }, bold = { "pushRemote" } })
    :build()

  p:show()

  return p
end

return M
