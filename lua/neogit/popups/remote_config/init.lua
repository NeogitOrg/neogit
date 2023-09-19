local M = {}
local popup = require("neogit.lib.popup")

function M.create(remote)
  local p = popup
    .builder()
    :name("NeogitRemoteConfigPopup")
    :config_heading("Configure remote")
    :config("u", "remote." .. remote .. ".url")
    :config("U", "remote." .. remote .. ".fetch")
    :config("s", "remote." .. remote .. ".pushurl")
    :config("S", "remote." .. remote .. ".push")
    :config("O", "remote." .. remote .. ".tagOpt", {
      options = {
        { display = "", value = "" },
        { display = "--no-tags", value = "--no-tags" },
        { display = "--tags", value = "--tags" },
      },
    })
    :config_heading("")
    :config_heading("Configure repository defaults")
    :config(
      "P",
      "remote.pushDefault",
      { options = require("neogit.popups.branch_config.actions").remotes_for_config() }
    )
    :config("d", "neogit.remoteAddSetRemotePushDefault", {
      options = {
        { display = "ask", value = "ask" },
        { display = "ask-if-unset", value = "ask-if-unset" },
        { display = "", value = "" },
      },
    })
    :env({ highlight = { remote } })
    :build()

  p:show()

  return p
end

return M
