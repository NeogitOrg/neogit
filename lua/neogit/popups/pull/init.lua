local actions = require("neogit.popups.pull.actions")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local M = {}

local function pushRemote_description()
  local current = git.repo.head.branch
  local pushRemote = git.branch.pushRemote()

  if current and pushRemote then
    return pushRemote .. "/" .. current
  elseif current then
    return "pushRemote, setting that"
  end
end

local function upstream_description()
  local upstream = git.repo.upstream.ref

  if upstream then
    return upstream
  else
    return "@{upstream}, creating it"
  end
end

function M.create()
  local current = git.repo.head.branch

  local p = popup
    .builder()
    :name("NeogitPullPopup")
    :config_if(current, "r", "branch." .. (current or "") .. ".rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "pull.rebase:" .. (git.config.get("pull.rebase").value or ""), value = "" },
      },
    })
    :switch("f", "ff-only", "Fast-forward only")
    :switch("r", "rebase", "Rebase local commits")
    :switch("a", "autostash", "Autostash")
    :group_heading_if(current, "Pull into " .. current .. " from")
    :group_heading_if(not current, "Pull from")
    :action_if(current, "p", pushRemote_description(), actions.from_pushremote)
    :action_if(current, "u", upstream_description(), actions.from_upstream)
    :action("e", "elsewhere", actions.from_elsewhere)
    :new_action_group("Configure")
    :action("C", "Set variables...", actions.configure)
    :env({ highlight = current })
    :build()

  p:show()

  return p
end

return M
