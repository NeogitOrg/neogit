local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")

local row = Ui.row
local text = Ui.text
local map = util.map

local M = {}

local function format_branches(list)
  local branches = {}
  for _, name in ipairs(list) do
    local name_formatted = name:match("^remotes/(.*)") or name
    if not name_formatted:match("^(.*)/HEAD") then
      table.insert(branches, name_formatted)
    end
  end
  return branches
end

function M.View(branches)
  return map(format_branches(branches), function(branch_name)
    return row {
      text(branch_name),
    }
  end)
end

return M
