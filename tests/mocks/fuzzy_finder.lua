local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {
  value = "",
}

FuzzyFinderBuffer.open_async = function()
  if type(M.value) == "table" then
    return table.remove(M.value, 1)
  else
    return M.value
  end
end

return M
