local Ui = require("neogit.lib.ui")

local row = Ui.row
local text = Ui.text

local util = require("neogit.lib.util")

local M = {}

local function render_line(commit)
  local content = {
    text(commit.oid:sub(1, 7), { highlight = "Number" }),
    text(" "),
    text(commit.graph, { highlight = "Character" }),
    text(" "),
    text(util.str_truncate(table.concat(commit.description), 100)),
  }

  if commit.author and commit.rel_date then
    local content_length = 0
    for _, t in ipairs(content) do
      content_length = content_length + #t.value
    end

    local win_width = vim.fn.winwidth(0)
    local date_padding = 15 - #commit.rel_date
    local left_padding = win_width - content_length - #commit.author - #commit.rel_date - date_padding - 8

    table.insert(content, text((" "):rep(left_padding)))
    table.insert(content, text(commit.author, { highlight = "String" }))
    table.insert(content, text((" "):rep(date_padding)))
    table.insert(content, text(commit.rel_date, { highlight = "Special" }))
  end

  return content
end

function M.View(commits, commit_at_cursor)
  local res = {}

  if commit_at_cursor then
    table.insert(res, row(render_line(commit_at_cursor)))
    table.insert(res, row {})
  end

  for _, commit in ipairs(commits) do
    if commit.oid then
      table.insert(res, row(render_line(commit)))
    else
      table.insert(
        res,
        row {
          text((" "):rep(8)),
          text(commit.graph, { highlight = "Character" })
        }
      )
    end
  end

  return res
end

return M
