local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")

local row = Ui.row
local text = Ui.text

local M = {}

local function length(content)
  local content_length = 0
  for _, t in ipairs(content) do
    content_length = content_length + #t.value
  end
  return content_length
end

local function render_line_left(commit)
  local content = {
    text(commit.oid:sub(1, 7), { highlight = "Comment" }),
    text(" "),
    text(commit.graph, { highlight = "Include" }),
    text(" "),
  }

  return content, length(content)
end

local function render_line_right(commit)
  local author = util.str_truncate(commit.author, 19, "")
  local content = {
    text(" "),
    text(author, { highlight = "Constant" }),
    text((" "):rep(20 - #author)),
    text(commit.rel_date, { highlight = "Special" }),
    text((" "):rep(10 - #commit.rel_date)),
  }

  return content, length(content)
end

local function render_line(commit)
  local win_width = vim.fn.winwidth(0)

  local left_content, left_content_length = render_line_left(commit)
  local right_content, right_content_length = render_line_right(commit)

  local center_spacing = win_width - left_content_length - right_content_length - 6

  local message = util.str_truncate(table.concat(commit.description), center_spacing - 3)
  table.insert(left_content, text(message))
  table.insert(left_content, text((" "):rep(center_spacing - #message)))

  return util.merge(left_content, right_content)
end

local function render_graph_line(commit)
  return {
    text((" "):rep(8)),
    text(commit.graph, { highlight = "Include" })
  }
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
      table.insert(res, row(render_graph_line(commit)))
    end
  end

  return res
end

return M
