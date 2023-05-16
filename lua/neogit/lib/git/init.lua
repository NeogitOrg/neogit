local cli = require("neogit.lib.git.cli")

local M = {}

M.create = function (directory, sync)
  sync = sync or false

  if sync then
    cli.init.args(directory).call_sync()
  else
    cli.init.args(directory).call()
  end
end

return M
