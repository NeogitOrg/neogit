local actions = require("neogit.popups.fetch.actions")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local M = {}

local function pushRemote_label()
  return git.branch.pushRemote() or "pushRemote, setting that"
end

function M.create()
  local upstream = actions.upstream()

  local p = popup
    .builder()
    :name("NeogitFetchPopup")
    :switch("p", "prune", "Prune deleted branches")
    :switch("t", "tags", "Fetch all tags")
    :group_heading("Fetch from")
    :action("p", pushRemote_label(), actions.fetch_from_pushremote)
    :action_if(upstream ~= nil, "u", upstream, actions.fetch_from_upstream)
    :action("e", "elsewhere", actions.fetch_from_elsewhere)
    :action("a", "all remotes", actions.fetch_from_all_remotes)
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
