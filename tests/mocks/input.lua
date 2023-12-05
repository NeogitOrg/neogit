local input = require("neogit.lib.input")
---@class InputMock
local M = {
  ---@type string[]
  values = {},
  confirmed = true,
  choice = nil,
}

input.get_user_input = function(_, default)
  local value = table.remove(M.values, 1)
  if value == "" and default then
    return default
  else
    return value
  end
end

input.get_confirmation = function(_, _)
  return M.confirmed
end

input.get_choice = function(_, _)
  return M.choice
end

return M
