local M = {}
function M.echo(value)
  local notification = require("neogit.lib.notification")
  notification.create("Echo: " .. value)
end

return M
