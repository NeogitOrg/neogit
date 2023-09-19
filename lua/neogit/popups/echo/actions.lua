--- This popup is for unit testing purposes and is not associated to any git command.
local notification = require("neogit.lib.notification")
local M = {}

function M.echo(value)
  notification.info("Echo: " .. value)
end

return M
