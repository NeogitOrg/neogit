local actions = require("neogit.popups.pull.actions")
local git = require("neogit.lib.git")
local popup = require("neogit.lib.popup")

local M = {}

function M.create()
  local current = git.branch.current()
  local show_config = current ~= "" and current ~= "(detached)"
  local pull_rebase_entry = git.config.get("pull.rebase")
  local pull_rebase = pull_rebase_entry:is_set() and pull_rebase_entry.value or "false"

  local p = popup
    .builder()
    :name("NeogitPullPopup")
    :config_if(show_config, "r", "branch." .. (current or "") .. ".rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "pull.rebase:" .. pull_rebase, value = "" },
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
      highlight = { current, git.branch.upstream(), git.branch.pushRemote_ref() },
      bold = { "pushRemote", "@{upstream}" },
    })
    :build()

  p:show()

  return p
end

return M
