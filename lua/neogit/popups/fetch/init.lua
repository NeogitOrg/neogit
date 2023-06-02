local actions = require("neogit.popups.fetch.actions")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local M = {}

local function pushRemote_description()
  return git.branch.pushRemote() or "pushRemote, setting that"
end

local function upstream_description()
  return git.repo.upstream.remote or "@{upstream}, creating it"
end

function M.create()
  local p = popup
    .builder()
    :name("NeogitFetchPopup")
    :switch("p", "prune", "Prune deleted branches")
    :switch("t", "tags", "Fetch all tags")
    :group_heading("Fetch from")
    :action("p", pushRemote_description(), actions.fetch_from_pushremote)
    :action("u", upstream_description(), actions.fetch_from_upstream)
    :action("e", "elsewhere", actions.fetch_from_elsewhere)
    :action("a", "all remotes", actions.fetch_from_all_remotes)
    :new_action_group("Fetch")
    :action("o", "another branch")
    :action("r", "explicit refspec")
    :action("m", "submodules")
    :new_action_group("Configure")
    :action("C", "Set variables...", actions.set_variables)
    :env(
      {
        highlight = { git.branch.pushRemote() },
        bold = { "pushRemote", "@{upstream}" }
      }
    )
    :build()

  p:show()

  return p
end

return M
