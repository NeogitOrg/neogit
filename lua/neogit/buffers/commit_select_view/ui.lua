local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")

local row = Ui.row
local text = Ui.text
local map = util.map

local M = {}

function M.View(commits)
  local show_graph = true
  return map(commits, function(commit)
    return row {
      text(commit.oid:sub(1, 7), { highlight = "Number" }),
      text(" "),
      text(show_graph and ("* "):rep(commit.level + 1) or "* ", { highlight = "Character" }),
      text(" "),
      text(table.concat(commit.description)),
    }
  end)
end

return M
