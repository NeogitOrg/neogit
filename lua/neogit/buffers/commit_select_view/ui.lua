local Ui = require("neogit.lib.ui")

local row = Ui.row
local text = Ui.text

local M = {}

function M.View(commits, commit_at_cursor)
  local show_graph = true

  local res = {}
  if commit_at_cursor then
    table.insert(
      res,
      row {
        text(commit_at_cursor.oid:sub(1, 7), { highlight = "Number" }),
        text(" "),
        text(show_graph and ("* "):rep(commit_at_cursor.level + 1) or "* ", { highlight = "Character" }),
        text(" "),
        text(table.concat(commit_at_cursor.description)),
      }
    )

    table.insert(res, row {})
  end

  for _, commit in ipairs(commits) do
    table.insert(
      res,
      row {
        text(commit.oid:sub(1, 7), { highlight = "Number" }),
        text(" "),
        text(show_graph and ("* "):rep(commit.level + 1) or "* ", { highlight = "Character" }),
        text(" "),
        text(table.concat(commit.description)),
      }
    )
  end

  return res
end

return M
