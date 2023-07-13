local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {
  value = "",
}

FuzzyFinderBuffer.open_async = function()
  return M.value
end

return M
