local Component = require("neogit.lib.ui.component")
local util = require("neogit.lib.util")
local Renderer = require("neogit.lib.ui.renderer")

local filter = util.filter

---@class UiComponent
---@field tag string
---@field options table Component props or arguments
---@field children UiComponent[]

---@class Ui
---@field buf number
---@field layout table
local Ui = {}
Ui.__index = Ui

---@param buf Buffer
---@return Ui
function Ui.new(buf)
  return setmetatable({ buf = buf, layout = {} }, Ui)
end

function Ui._print_component(indent, c, _options)
  local output = string.rep("  ", indent)
  if c.position then
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
    if k ~= "tag" then
      output = output .. " " .. k .. "=" .. tostring(v)
    end
  end

  print(output)
end

function Ui._visualize_tree(indent, components, options)
  for _, c in ipairs(components) do
    Ui._print_component(indent, c, options)
    if c.tag == "col" or c.tag == "row" then
      Ui._visualize_tree(indent + 1, c.children, options)
    end
  end
end

function Ui._find_component(components, f, options)
  for _, c in ipairs(components) do
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

  return nil
end

---@class FindOptions

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

function Ui:get_fold_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return self:find_component(function(c)
    return c.options.foldable and c:is_under_cursor(cursor)
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

function Ui:get_item_options()
  local stack = self:get_component_stack_under_cursor()
  return stack[#stack].options or {}
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

function Ui:render(...)
  self.layout = { ... }
  self.layout = filter(self.layout, function(x)
    return type(x) == "table"
  end)

  self:update()
end

-- This shouldn't be called often as it completely rewrites the whole buffer
function Ui:update()
  local root = Component.new(function()
    return {
      tag = "_root",
      children = self.layout,
    }
  end)()

  local ns = self.buf:create_namespace("VirtualText")
  local buffer = Renderer:new(ns):render(root)

  self.buf:unlock()
  self.buf:clear()
  self.buf:clear_namespace("default")
  self.buf:resize(#buffer.line)
  self.buf:set_lines(0, -1, false, buffer.line)
  self.buf:set_highlights(buffer.highlight)
  self.buf:set_extmarks(buffer.extmark)
  self.buf:set_line_highlights(buffer.line_highlight)
  self.buf:set_folds(buffer.fold)
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
    __index = {
      render = function(self)
        return self.value
      end
    }
  }
end)

Ui.Component = Component

return Ui
