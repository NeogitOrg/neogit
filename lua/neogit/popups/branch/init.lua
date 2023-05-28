local M = {}

local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")
local actions = require("neogit.popups.branch.actions")
local config_actions = require("neogit.popups.branch_config.actions")

function M.create()
  local current_branch = git.branch.current()

  local p = popup
    .builder()
    :name("NeogitBranchPopup")
    :switch("r", "recurse-submodules", "Recurse submodules when checking out an existing branch")
    :config_if(current_branch, "d", "branch." .. (current_branch or "") .. ".description")
    :config_if(current_branch, "u", "branch." .. (current_branch or "") .. ".merge", {
      callback = config_actions.merge_config(current_branch),
    })
    :config_if(current_branch, "m", "branch." .. (current_branch or "") .. ".remote", { passive = true })
    :config_if(current_branch, "r", "branch." .. (current_branch or "") .. ".rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "pull.rebase:" .. (git.config.get("pull.rebase").value or ""), value = "" },
      },
    })
    :config_if(current_branch, "p", "branch." .. (current_branch or "") .. ".pushRemote", {
      options = config_actions.remotes_for_config(),
    })
    :group_heading("Checkout")
    :action("b", "branch/revision", actions.checkout_branch_revision)
    :action("l", "local branch", actions.checkout_local_branch)
    :new_action_group()
    :action("c", "new branch", actions.checkout_create_branch)
    :action("s", "new spin-off")
    :action("w", "new worktree")
    :new_action_group("Create")
    :action("n", "new branch", actions.create_branch)
    :action("S", "new spin-out")
    :action("W", "new worktree")
    :new_action_group("Do")
    :action("C", "Configure...", actions.configure_branch)
    :action("m", "rename", actions.rename_branch)
    :action("X", "reset", actions.reset_branch)
    :action("D", "delete", actions.delete_branch)
    :build()

  p:show()

  return p
end

return M
