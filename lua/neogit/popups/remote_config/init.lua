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
    :env({ highlight = { remote } })
    :build()

  p:show()

  return p
end

return M
