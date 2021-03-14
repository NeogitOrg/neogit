local input = require'neogit.lib.input'
local M = {
  value = ''
}

input.get_user_input = function (_)
  return M.value
end

input.get_user_input_with_completion = function (_, _)
  return M.value
end


return M

