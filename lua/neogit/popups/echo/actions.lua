--- This popup is for unit testing purposes and is not associated to any git command.

local M = {}
function M.echo(value)
  local notification = require("neogit.lib.notification")
  notification.create("Echo: " .. value)
end

return M
