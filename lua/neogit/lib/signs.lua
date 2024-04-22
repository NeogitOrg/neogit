local config = require("neogit.config")
local M = {}

local signs = { NeogitBlank = " " }

function M.get(name)
  local sign = signs[name]
  if sign == "" then
    return " "
  else
    return sign
  end
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
