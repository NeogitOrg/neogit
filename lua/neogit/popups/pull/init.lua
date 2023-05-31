local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.pull.actions")
local git = require("neogit.lib.git")

local M = {}

local function pushRemote_description()
  local current = git.branch.current()
  local pushRemote = actions.pushRemote()

  if current and pushRemote then
    return pushRemote .. "/" .. current
  elseif current then
    return "pushRemote, setting that"
  end
end

local function upstream_description()
  local upstream = git.branch.get_upstream_sync()

  if upstream then
    return upstream.remote .. "/" .. upstream.branch
  else
    return "@{upstream}, creating it"
  end
end

function M.create()
  local current = git.branch.current()

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
