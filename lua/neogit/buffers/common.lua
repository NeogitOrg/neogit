local Ui = require 'neogit.lib.ui'
local Component = require 'neogit.lib.ui.component'
local util = require 'neogit.lib.util'

local text = Ui.text
local col = Ui.col
local row = Ui.row
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
    text(diff.kind .. " " .. diff.file),
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
  local children = filter(props.items, function(x) 
    return type(x) == "table" 
  end)

  if props.separator then
    children = intersperse(children, text(props.separator))
  end

  local container = col

  if props.horizontal then
    container = row
  end

  return container.tag("List")(children)
end)

M.Grid = Component.new(function(props)
  props = vim.tbl_extend("force", {
    gap = 0,
    columns = true, -- whether the items represents a list of columns instead of a list of row
    items = {}
  }, props)

  if props.columns then
    local new_items = {}
    local row_count = 0
    for i=1,#props.items do
      local l = #props.items[i]

      if l > row_count then
        row_count = l
      end
    end
    for _=1,row_count do
      table.insert(new_items, {})
    end
    for i=1,#props.items do
      for j=1,row_count do
        local x = props.items[i][j] or text ""
        table.insert(new_items[j], x)
      end
    end
    props.items = new_items
  end

  local rendered = {}
  local column_widths = {}

  for i=1,#props.items do
    local children = {}

    if i ~= 1 then
      children = map(range(props.gap), function() 
        return text "" 
      end)
    end
    -- current row
    local r = props.items[i]

    for j=1,#r do
      local item = r[j]
      local c = props.render_item(item)

      if c.tag ~= "text" and c.tag ~= "row" then
        error("Grid component only supports text and row components for now")
      end

      local c_width = c:get_width()
      children[j] = c

      if c_width > (column_widths[j] or 0) then
        column_widths[j] = c_width
      end
    end

    rendered[i] = row(children)
  end

  for i=1,#rendered do
    -- current row
    local r = rendered[i]

    for j=1,#r.children do
      local item = r.children[j]
      local gap_str = ""
      local column_width = column_widths[j]

      if j ~= 1 then
        gap_str = string.rep(" ", props.gap)
      end

      if item.tag == "text" then
        item.value = gap_str .. string.format("%" .. column_width .. "s", item.value)
      elseif item.tag == "row" then
        table.insert(item.children, 1, text(gap_str))
        local width = item:get_width()
        local remaining_width = column_width - width + props.gap
        table.insert(item.children, text(string.rep(" ", remaining_width)))
      else
        error("TODO")
      end
    end
  end

  return col(rendered)
end)


return M
