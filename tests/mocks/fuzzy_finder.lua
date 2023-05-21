local FuzzyFinderBuffer = require("neogit.buffers.fuzzy_finder")

local M = {
  value = "",
}

FuzzyFinderBuffer.open_sync = function()
  return M.value
end

return M
