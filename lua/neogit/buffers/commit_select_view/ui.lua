local Ui = require("neogit.lib.ui")
local util = require("neogit.lib.util")

local row = Ui.row
local text = Ui.text

local M = {}

local function highlight_ref_name(name)
  return name:match("/") and "String" or "Macro"
end

local function length(content)
  local content_length = 0
  for _, t in ipairs(content) do
    content_length = content_length + vim.fn.strdisplaywidth(t.value)
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
  local author = util.str_truncate(commit.author_name, 19, "")
  local content = {
    text(" "),
    text(author, { highlight = "Constant" }),
    text((" "):rep(20 - vim.fn.strdisplaywidth(author))),
  }

  if commit.rel_date:match("^%d ") then
    commit.rel_date = " " .. commit.rel_date
  end

  table.insert(content, text(commit.rel_date, { highlight = "Special" }))
  table.insert(content, text((" "):rep(10 - #commit.rel_date)))

  return content, length(content)
end

local function render_line_center(commit, max_width)
  local content = {}

  if commit.ref_name ~= "" then
    local ref_name, _ = commit.ref_name:gsub("HEAD %-> ", "")
    local remote_name, local_name = unpack(vim.split(ref_name, ", "))

    if local_name then
      table.insert(content, text(local_name, { highlight = highlight_ref_name(local_name) }))
      table.insert(content, text(" "))

      max_width = max_width - #local_name - 1
    end

    if remote_name then
      table.insert(content, text(remote_name, { highlight = highlight_ref_name(remote_name) }))
      table.insert(content, text(" "))

      max_width = max_width - #remote_name - 1
    end
  end

  local message = util.str_truncate(table.concat(commit.description), max_width)

  table.insert(content, text(message))
  table.insert(content, text((" "):rep(max_width - #message)))

  return content
end

local function render_line(commit)
  local left_content, left_content_length = render_line_left(commit)
  local right_content, right_content_length = render_line_right(commit)

  local center_spacing = vim.fn.winwidth(0) - 8 - left_content_length - right_content_length
  local center_content = render_line_center(commit, center_spacing)

  return util.merge(left_content, center_content, right_content)
end

local function render_graph_line(commit)
  return {
    text((" "):rep(8)),
    text(commit.graph, { highlight = "Include" }),
  }
end

function M.View(commits)
  local res = {}

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
