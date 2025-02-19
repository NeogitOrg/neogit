local M = {}

local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")
local actions = require("neogit.popups.branch.actions")
local worktree_actions = require("neogit.popups.worktree.actions")
local config_actions = require("neogit.popups.branch_config.actions")

function M.create(env)
  local current_branch = git.branch.current() or ""
  local show_config = current_branch ~= ""
  local pull_rebase_entry = git.config.get("pull.rebase")
  local pull_rebase = pull_rebase_entry:is_set() and pull_rebase_entry.value or "false"
  local has_upstream = git.branch.upstream() ~= nil

  local p = popup
    .builder()
    :name("NeogitBranchPopup")
    :config_heading_if(show_config, "Configure branch")
    :config_if(show_config, "d", "branch." .. current_branch .. ".description", {
      fn = config_actions.description_config(current_branch),
    })
    :config_if(show_config, "u", "branch." .. current_branch .. ".merge", {
      fn = config_actions.merge_config(current_branch),
      callback = function(popup)
        for _, config in ipairs(popup.state.config) do
          if config.name == "branch." .. current_branch .. ".remote" then
            config.value = tostring(config.entry:refresh():read() or "")
          end
        end
      end,
    })
    :config_if(show_config, "m", "branch." .. current_branch .. ".remote", { passive = true })
    :config_if(show_config, "R", "branch." .. current_branch .. ".rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "pull.rebase:" .. pull_rebase, value = "" },
      },
    })
    :config_if(show_config, "p", "branch." .. current_branch .. ".pushRemote", {
      options = config_actions.remotes_for_config(),
    })
    :switch("r", "recurse-submodules", "Recurse submodules when checking out an existing branch")
    :group_heading("Checkout")
    :action("b", "branch/revision", actions.checkout_branch_revision)
    :action("l", "local branch", actions.checkout_local_branch)
    :action("r", "recent branch", actions.checkout_recent_branch)
    :new_action_group()
    :action("c", "new branch", actions.checkout_create_branch)
    :action("s", "new spin-off", actions.spin_off_branch)
    :action("w", "new worktree", worktree_actions.checkout_worktree)
    :new_action_group("Create")
    :action("n", "new branch", actions.create_branch)
    :action("S", "new spin-out", actions.spin_out_branch)
    :action("W", "new worktree", worktree_actions.create_worktree)
    :new_action_group("Do")
    :action("C", "Configure...", actions.configure_branch)
    :action("m", "rename", actions.rename_branch)
    :action("X", "reset", actions.reset_branch)
    :action("D", "delete", actions.delete_branch)
    :action_if(has_upstream, "o", "pull request", actions.open_pull_request)
    :env(env)
    :build()

  p:show()

  return p
end

return M
