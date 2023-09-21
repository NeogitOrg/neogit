local M = {}

local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")
local actions = require("neogit.popups.branch_config.actions")

function M.create(branch)
  branch = branch or git.branch.current()
  local g_pull_rebase = git.config.get_global("pull.rebase")
  local pull_rebase_entry = git.config.get("pull.rebase")
  local pull_rebase = pull_rebase_entry:is_set() and pull_rebase_entry.value or "false"

  local p = popup
    .builder()
    :name("NeogitBranchConfigPopup")
    :config_heading("Configure branch")
    :config("d", "branch." .. branch .. ".description")
    :config("u", "branch." .. branch .. ".merge", { fn = actions.merge_config(branch) })
    :config("m", "branch." .. branch .. ".remote", { passive = true })
    :config("r", "branch." .. branch .. ".rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "pull.rebase:" .. pull_rebase, value = "" },
      },
    })
    :config("p", "branch." .. branch .. ".pushRemote", { options = actions.remotes_for_config() })
    :config_heading("")
    :config_heading("Configure repository defaults")
    :config("R", "pull.rebase", {
      callback = actions.update_pull_rebase(),
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        {
          display = "global:" .. g_pull_rebase.value,
          value = "",
          condition = function()
            return g_pull_rebase:is_set()
          end,
        },
      },
    })
    :config("P", "remote.pushDefault", { options = actions.remotes_for_config() })
    :config("b", "neogit.baseBranch")
    :config("A", "neogit.askSetPushDefault", {
      options = {
        { display = "ask", value = "ask" },
        { display = "ask-if-unset", value = "" },
        { display = "never", value = "never" },
      },
    })
    :config_heading("")
    :config_heading("Configure branch creation")
    :config("as", "branch.autoSetupMerge", {
      options = {
        { display = "always", value = "always" },
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "inherit", value = "inherit" },
        { display = "simple", value = "simple" },
        { display = "default:true", value = "" },
      },
    })
    :config("ar", "branch.autoSetupRebase", {
      options = {
        { display = "always", value = "always" },
        { display = "local", value = "local" },
        { display = "remote", value = "remote" },
        { display = "never", value = "never" },
        { display = "default:never", value = "" },
      },
    })
    :env({ highlight = { branch } })
    :build()

  p:show()

  return p
end

return M
