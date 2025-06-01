local M = {}
local popup = require("neogit.lib.popup")
local notification = require("neogit.lib.notification")
local git = require("neogit.lib.git")

---@param env table
function M.create(env)
  local remotes = git.remote.list()
  if vim.tbl_isempty(remotes) then
    notification.warn("Repo has no configured remotes.")
    return
  end

  local remote = env.remote

  if not remote then
    if vim.tbl_contains(remotes, "origin") then
      remote = "origin"
    elseif #remotes == 1 then
      remote = remotes[1]
    else
      notification.error("Cannot infer remote.")
      return
    end
  end

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
