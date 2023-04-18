local M = {}
local popup = require("neogit.lib.popup")
local git = require("neogit.lib.git")

local function remotes_for_config()
  local remotes = {
    { display = "", value = "" },
  }

  for _, name in ipairs(git.remote.list()) do
    table.insert(remotes, { display = name, value = name })
  end

  return remotes
end

function M.create(branch)
  branch = branch or git.branch.current()

  local p = popup
    .builder()
    :name("NeogitBranchConfigPopup")
    :config_heading("Configure branch")
    :config("d", "branch." .. branch .. ".description")
    :config("u", "branch." .. branch .. ".merge", {
      callback = function(popup, c)
        print("TODO - open branch picker")
      end,
    })
    :config("m", "branch." .. branch .. ".remote", { passive = true })
    :config("r", "branch." .. branch .. ".rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "pull.rebase:" .. git.config.get("pull.rebase").value, value = "" },
      },
    })
    :config("p", "branch." .. branch .. ".pushRemote", {
      options = remotes_for_config(),
    })
    :config_heading("")
    :config_heading("Configure repository defaults")
    :config("R", "pull.rebase", {
      options = {
        { display = "true", value = "true" },
        { display = "false", value = "false" },
        { display = "global:" .. git.config.get_global("pull.rebase"), value = "" },
      },
    })
    :config("P", "remote.pushDefault", {
      options = remotes_for_config(),
    })
    :config("b", "neogit.baseBranch")
    :config_heading("")
    :config_heading("Configure branch creation")
    :config("as", "branch.autoSetupMerge", {
      options = {
        { display = "always", value = "always" },
        { display = "true", value = "true" },
        { display = "false", value = "false" },
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
    :env({ highlight = branch })
    :build()

  p:show()

  return p
end

return M
