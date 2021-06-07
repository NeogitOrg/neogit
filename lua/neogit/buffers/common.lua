local Ui = require 'neogit.lib.ui'
local Component = require 'neogit.lib.ui.component'
local util = require 'neogit.lib.util'

local text = Ui.text
local col = Ui.col
local map = util.map
local filter = util.filter
local intersperse = util.intersperse
local range = util.range

local M = {}

local diff_add_matcher = vim.regex('^+')
local diff_delete_matcher = vim.regex('^-')

M.Diff = Component.new(function(diff)
  local hunk_props = map(diff.hunks, function(hunk) 
    local header = diff.lines[hunk.diff_from]

    local content = map(range(hunk.diff_from + 1, hunk.diff_to), function(i)
      return diff.lines[i]
    end)

    return {
      header = header,
      content = content
    }
  end)

  return col.tag("Diff") {
    text(diff.kind, " ", diff.file),
    col.tag("HunkList")(map(hunk_props, M.Hunk))
  }
end)

local HunkLine = Component.new(function(line)
  local sign

  if diff_add_matcher:match_str(line) then
    sign = 'NeogitDiffAdd'
  elseif diff_delete_matcher:match_str(line) then
    sign = 'NeogitDiffDelete'
  end

  return text(line, { sign = sign })
end)

M.Hunk = Component.new(function(props)
  return col.tag("Hunk") {
    text.sign("NeogitHunkHeader")(props.header),
    col.tag("HunkContent")(map(props.content, HunkLine))
  }
end)

M.List = Component.new(function(props)
  local children = filter(props.items, function(x) return type(x) == "table" end)

  if props.separator then
    children = intersperse(children, text(props.separator))
  end

  local container = col

  if props.horizontal then
    container = row
  end

  return container.tag("List")(children)
end)

return M
