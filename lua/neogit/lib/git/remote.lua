local cli = require("neogit.lib.git.cli")
local notif = require("neogit.lib.notification")
local a = require("plenary.async")

local M = {}

function M.add(name, url)
  a.util.scheduler()

  local result = cli.remote.add.arg_list({ name, url }).call()
  if result.code ~= 0 then
    notif.create("Couldn't add remote", vim.log.levels.ERROR)
  end

  return result
end

return M
