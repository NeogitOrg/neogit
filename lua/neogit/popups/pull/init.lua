local actions = require("neogit.popups.pull.actions")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local M = {}

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
    :action_if(current, "p", git.branch.pushRemote_label(), actions.from_pushremote)
    :action_if(current, "u", git.branch.upstream_label(), actions.from_upstream)
    :action("e", "elsewhere", actions.from_elsewhere)
    :new_action_group("Configure")
    :action("C", "Set variables...", actions.configure)
    :env({
      highlight = { current, git.repo.upstream.ref, git.branch.pushRemote_ref() },
      bold = { "pushRemote", "@{upstream}" },
    })
    :build()

  p:show()

  return p
end

return M
