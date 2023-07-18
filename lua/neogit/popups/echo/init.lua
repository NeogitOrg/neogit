--- This popup is for unit testing purposes and is not associated to any git command.

local popup = require("neogit.lib.popup")
local actions = require("neogit.popups.echo.actions")

local M = {}

function M.create(...)
  local args = { ... }
  local p = popup.builder():name("NeogitEchoPopup")
  for k, v in ipairs(args) do
    p:action(tostring(k), tostring(v), function()
      actions.echo(v)
    end)
  end

  local p = p:build()

  p:show()

  return p
end

return M
