local config = require("neogit.config")
local M = {}

local signs = {}

function M.get(name)
  return signs[name]
end

function M.setup()
  if not config.values.disable_signs then
    for key, val in pairs(config.values.signs) do
      if key == "hunk" or key == "item" or key == "section" then
        signs["NeogitClosed" .. key] = val[1]
        signs["NeogitOpen" .. key] = val[2]
      end
    end
  end
end

return M
