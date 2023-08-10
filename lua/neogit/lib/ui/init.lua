local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")

local filter = util.filter

---@class UiComponent
---@field tag string
---@field options table Component props or arguments
---@field children UiComponent[]

---@class Ui
---@field buf number
---@field layout table
local Ui = {}

function Ui.new(buf)
  local this = {
    buf = buf,
    layout = {},
  }
  setmetatable(this, { __index = Ui })
  return this
end

function Ui._print_component(indent, c, _options)
  local output = string.rep("  ", indent)
  if c.options.hidden then
    output = output .. "(H)"
  elseif c.position then
    local text = ""
    if c.position.row_start == c.position.row_end then
      text = c.position.row_start
    else
      text = c.position.row_start .. " - " .. c.position.row_end
    end

    if c.position.col_end ~= -1 then
      text = text .. " | " .. c.position.col_start .. " - " .. c.position.col_end
    end

    output = output .. "[" .. text .. "]"
  end

  output = output .. " " .. c:get_tag()

  if c.tag == "text" then
    output = output .. " '" .. c.value .. "'"
  end

  for k, v in pairs(c.options) do
    if k ~= "tag" and k ~= "hidden" then
      output = output .. " " .. k .. "=" .. tostring(v)
    end
  end

  print(output)
end

function Ui._visualize_tree(indent, components, options)
  for _, c in ipairs(components) do
    Ui._print_component(indent, c, options)
    if
      (c.tag == "col" or c.tag == "row")
      and not (options.collapse_hidden_components and c.options.hidden)
    then
      Ui._visualize_tree(indent + 1, c.children, options)
    end
  end
end

function Ui._find_component(components, f, options)
  for _, c in ipairs(components) do
    if (options.include_hidden and c.options.hidden) or not c.options.hidden then
      if c.tag == "col" or c.tag == "row" then
        local res = Ui._find_component(c.children, f, options)

        if res then
          return res
        end
      end

      if f(c) then
        return c
      end
    end
  end

  return nil
end

---@class FindOptions
---@field include_hidden boolean

--- Finds a ui component in the buffer
---
---@param f fun(c: UiComponent): boolean
---@param options FindOptions|nil
function Ui:find_component(f, options)
  return Ui._find_component(self.layout, f, options or {})
end

function Ui._find_components(components, f, result, options)
  for _, c in ipairs(components) do
    if c.tag == "col" or c.tag == "row" then
      Ui._find_components(c.children, f, result, options)
    end

    if f(c) then
      table.insert(result, c)
    end
  end
end

function Ui:find_components(f, options)
  local result = {}
  Ui._find_components(self.layout, f, result, options or {})
  return result
end

function Ui:get_component_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return self:find_component(function(c)
    return c:is_under_cursor(cursor)
  end)
end

function Ui:get_component_on_line(line)
  return self:find_component(function(c)
    return c:is_under_cursor { line, 0 }
  end)
end

function Ui:get_component_stack_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return self:find_components(function(c)
    return c:is_under_cursor(cursor)
  end)
end

function Ui:get_component_stack_in_linewise_selection()
  local range = { vim.fn.getpos("v")[2], vim.fn.getpos(".")[2] }
  table.sort(range)
  local start, stop = unpack(range)

  return self:find_components(function(c)
    return c:is_in_linewise_range(start, stop)
  end)
end

function Ui:get_component_stack_on_line(line)
  return self:find_components(function(c)
    return c:is_under_cursor { line, 0 }
  end)
end

function Ui:get_commits_in_selection()
  local commits = util.filter_map(self:get_component_stack_in_linewise_selection(), function(c)
    if c.options.oid then
      return c.options.oid
    end
  end)

  -- Reversed so that the oldest commit is the first in the list
  return util.reverse(commits)
end

function Ui:get_commit_under_cursor()
  local stack = self:get_component_stack_under_cursor()
  return stack[#stack].options.oid
end

function Ui.visualize_component(c, options)
  Ui._print_component(0, c, options or {})
  if c.tag == "col" or c.tag == "row" then
    Ui._visualize_tree(1, c.children, options or {})
  end
end

function Ui.visualize_tree(components, options)
  print("root")
  Ui._visualize_tree(1, components, options or {})
end

function Ui:_render(first_line, first_col, parent, components, flags)
  local curr_line = first_line

  if flags.in_row then
    local col_start = first_col
    local col_end
    local highlights = {}
    local text = {}

    for i, c in ipairs(components) do
      c.parent = parent
      c.index = i

      if not c.options.hidden then
        c.position = {}
        c.position.row_start = curr_line - first_line + 1

        local highlight = c:get_highlight()

        if c.tag == "text" then
          local padding_left = flags.in_nested_row and "" or c:get_padding_left(i == 1)
          table.insert(text, 1, padding_left)

          col_start = col_start + #padding_left
          col_end = col_start + c:get_width()
          c.position.col_start = col_start
          c.position.col_end = col_end - 1

          if c.options.align_right then
            table.insert(text, c.value)
            table.insert(text, (" "):rep(c.options.align_right - #c.value))
          else
            table.insert(text, c.value)
          end

          if highlight then
            table.insert(highlights, {
              from = col_start,
              to = col_end,
              name = highlight,
            })
          end

          col_start = col_end
        elseif c.tag == "row" then
          flags.in_nested_row = true

          local padding_left = flags.in_nested_row and "" or c:get_padding_left(i == 1)
          local res = self:_render(curr_line, col_start, c, c.children, flags)

          flags.in_nested_row = false

          if c.position.col_end then
            c.position.col_end = c.position.col_end + #padding_left
          end

          table.insert(text, padding_left)
          table.insert(text, res.text)

          for _, h in ipairs(res.highlights) do
            h.to = h.to + #padding_left
            table.insert(highlights, h)
          end

          col_end = col_start + vim.fn.strdisplaywidth(res.text)
          c.position.col_start = col_start
          c.position.col_end = col_end
          col_start = col_end
        else
          error("The row component does not support having a `" .. c.tag .. "` as child")
        end

        c.position.row_end = c.position.row_start
      end
    end

    if flags.in_nested_row then
      return {
        text = table.concat(text),
        highlights = highlights,
      }
    end

    if not flags.hidden then
      self.buf:buffered_set_line(table.concat(text))

      for _, h in ipairs(highlights) do
        self.buf:buffered_add_highlight(curr_line - 1, h.from, h.to, h.name)
      end

      curr_line = curr_line + 1
    end
  else
    for i, c in ipairs(components) do
      c.parent = parent
      c.index = i

      if not c.options.hidden then
        c.position = {}
        c.position.row_start = curr_line - first_line + 1
        c.position.col_start = 0
        c.position.col_end = -1
        local sign = c:get_sign()
        local highlight = c:get_highlight()

        if c.tag == "text" then
          if not flags.hidden then
            self.buf:buffered_set_line(table.concat { c:get_padding_left(), c.value })

            if highlight then
              self.buf:buffered_add_highlight(
                curr_line - 1,
                c.position.col_start,
                c.position.col_end,
                highlight
              )
            end

            if sign then
              self.buf:buffered_place_sign(curr_line, sign, "hl")
            end

            curr_line = curr_line + 1
          end
        elseif c.tag == "col" then
          curr_line = curr_line + self:_render(curr_line, 0, c, c.children, flags)
        elseif c.tag == "row" then
          flags.in_row = true
          curr_line = curr_line + self:_render(curr_line, 0, c, c.children, flags)

          if not flags.hidden and sign then
            self.buf:buffered_place_sign(curr_line - 1, sign, "hl")
          end

          if not flags.hidden and c.options.virtual_text then
            local ns = self.buf:create_namespace("NeogitBufferVirtualText")
            self.buf:buffered_set_extmark(ns, curr_line - 2, 0, {
              hl_mode = "combine",
              virt_text = c.options.virtual_text,
              virt_text_pos = "right_align",
            })
          end

          flags.in_row = false
        end

        c.position.row_end = curr_line - first_line
      else
        flags.hidden = true

        if c.tag == "col" then
          self:_render(curr_line, 0, c, c.children, flags)
        elseif c.tag == "row" then
          flags.in_row = true
          self:_render(curr_line, 0, c, c.children, flags)
          flags.in_row = false
        end

        flags.hidden = false
      end
    end
  end

  return curr_line - first_line
end

function Ui:render(...)
  self.layout = { ... }
  self.layout = filter(self.layout, function(x)
    return type(x) == "table"
  end)
  self:update()
end

-- This shouldn't be called often as it completely rewrites the whole buffer
function Ui:update()
  self.buf:unlock()
  local lines_used = self:_render(
    1,
    0,
    Component.new(function()
      return {
        tag = "_root",
        children = self.layout,
      }
    end)(),
    self.layout,
    {}
  )
  self.buf:resize(lines_used)
  self.buf:flush_buffers()
  self.buf:lock()
end

--- Will only work if something has been rendered
function Ui:print_layout_tree(options)
  Ui.visualize_tree(self.layout, options)
end

function Ui:debug(...)
  Ui.visualize_tree({ ... }, {})
end

Ui.col = Component.new(function(children, options)
  return {
    tag = "col",
    children = filter(children, function(x)
      return type(x) == "table"
    end),
    options = options,
  }
end)

Ui.row = Component.new(function(children, options)
  return {
    tag = "row",
    children = filter(children, function(x)
      return type(x) == "table"
    end),
    options = options,
  }
end)

Ui.text = Component.new(function(value, options, ...)
  if ... then
    error("Too many arguments")
  end

  vim.validate {
    options = { options, "table", true },
  }

  return {
    tag = "text",
    value = value or "",
    options = type(options) == "table" and options or nil,
  }
end)

Ui.Component = require("neogit.lib.ui.component")

return Ui
