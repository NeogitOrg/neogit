local M = {}

local git = require("neogit.lib.git")

function M.remotes_for_config()
  local remotes = {
    { display = "", value = "" },
  }

  for _, name in ipairs(git.remote.list()) do
    table.insert(remotes, { display = name, value = name })
  end

  return remotes
end

return M
