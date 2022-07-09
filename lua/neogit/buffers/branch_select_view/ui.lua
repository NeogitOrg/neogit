local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")

local row = Ui.row
local text = Ui.text
local map = util.map

local M = {}

function M.View(branches)
  return map(branches, function(branch_name)
    return row {
      text(branch_name),
    }
  end)
end

return M
